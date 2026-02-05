// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract TransparentDonationTracker {
    
    struct Milestone {
        string description;
        uint256 targetAmount;
        uint256 amountRaised;
        bool completed;
        bool paidOut;
    }

    address public ngo;
    bool public projectActive = true;

    Milestone[] public milestones;

    // milestone → donor → amount donated
    mapping(uint256 => mapping(address => uint256)) public donations;
    mapping(address => uint256) public refunds;

    event MilestoneCreated(uint256 milestoneId, string description, uint256 targetAmount);
    event DonationReceived(address donor, uint256 milestoneId, uint256 amount);
    event MilestoneCompleted(uint256 milestoneId);
    event MilestonePaid(uint256 milestoneId, uint256 amount);
    event ProjectCancelled();
    event RefundWithdrawn(address donor, uint256 amount);

    modifier onlyNGO() {
        require(msg.sender == ngo, "Only NGO can call this");
        _;
    }

    modifier projectIsActive() {
        require(projectActive, "Project no longer active");
        _;
    }

    constructor() {
        ngo = msg.sender;
    }

    function createMilestone(string memory _description, uint256 _targetAmount)
        public
        onlyNGO
        projectIsActive
    {
        milestones.push(Milestone({
            description: _description,
            targetAmount: _targetAmount,
            amountRaised: 0,
            completed: false,
            paidOut: false
        }));

        emit MilestoneCreated(milestones.length - 1, _description, _targetAmount);
    }

    function donate(uint256 _milestoneId) public payable projectIsActive {
        require(_milestoneId < milestones.length, "Invalid milestone");
        Milestone storage m = milestones[_milestoneId];
        require(!m.completed, "Milestone completed");

        m.amountRaised += msg.value;
        donations[_milestoneId][msg.sender] += msg.value;

        emit DonationReceived(msg.sender, _milestoneId, msg.value);
    }

    function completeMilestone(uint256 _milestoneId) public onlyNGO {
        Milestone storage m = milestones[_milestoneId];
        require(!m.completed, "Already completed");

        m.completed = true;
        emit MilestoneCompleted(_milestoneId);
    }

    function withdrawMilestoneFunds(uint256 _milestoneId) public onlyNGO {
        Milestone storage m = milestones[_milestoneId];

        require(m.completed, "Milestone not completed");
        require(!m.paidOut, "Already paid");
        require(m.amountRaised > 0, "No funds");

        m.paidOut = true;
        uint256 amount = m.amountRaised;

        payable(ngo).transfer(amount);

        emit MilestonePaid(_milestoneId, amount);
    }

    function cancelProject() public onlyNGO {
        require(projectActive, "Already cancelled");
        projectActive = false;

        // Move every donation into each donor's refund balance
        for (uint256 i = 0; i < milestones.length; i++) {
            Milestone storage m = milestones[i];
            if (!m.paidOut && m.amountRaised > 0) {
                // No need to loop donors (Remix VM hates nested loops)
                // Just mark that donors can manually reclaim
                // (Demo-friendly implementation)
            }
        }

        emit ProjectCancelled();
    }

    function manualRefund(uint256 _milestoneId) public {
        uint256 donated = donations[_milestoneId][msg.sender];
        require(!milestones[_milestoneId].paidOut, "Milestone already paid");
        require(!milestones[_milestoneId].completed, "Already completed");
        require(!projectActive, "Project not cancelled");

        require(donated > 0, "No refund available");

        donations[_milestoneId][msg.sender] = 0;
        payable(msg.sender).transfer(donated);

        emit RefundWithdrawn(msg.sender, donated);
    }
}
