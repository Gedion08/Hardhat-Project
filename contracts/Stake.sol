// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


/**
 * @title StakingPool
 * @dev A smart contract for staking tokens with flexible or fixed staking periods
 * @dev Users can stake tokens, withdraw, and claim rewards based on the staking duration
 */
contract StakingPool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    // Staking-related variables
    IERC20 public stakingToken;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastStakeTimestamp;
    uint256 public rewardRate; // Reward rate per second
    uint256 public lastRewardTimestamp;

    // Staking periods with options: flexible, one week, two weeks, up to a maximum of sixty days
    uint256 constant FLEXIBLE_STAKING_PERIOD = 0;
    uint256 constant ONE_WEEK_STAKING_PERIOD = 1 weeks;
    uint256 constant TWO_WEEKS_STAKING_PERIOD = 2 weeks;
    uint256 constant MAX_STAKING_PERIOD = 60 days;

    // Set of supported staking periods
    EnumerableSet.UintSet private supportedStakingPeriods;

    // Events for tracking staking actions
    event Staked(address indexed user, uint256 amount, uint256 stakingPeriod);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    /**
     * @dev Constructor to initialize the StakingPool contract
     * @param _stakingToken Address of the staking token
     * @param _rewardRate Reward rate per second for staking
     * @param _initialOwner Address of the initial owner (used by Ownable)
     */
    constructor(address _stakingToken, uint256 _rewardRate, address _initialOwner) Ownable(_initialOwner) {
        stakingToken = IERC20(_stakingToken);
        rewardRate = _rewardRate;
        lastRewardTimestamp = block.timestamp;

        // Initialize supported staking periods
        supportedStakingPeriods.add(FLEXIBLE_STAKING_PERIOD);
        supportedStakingPeriods.add(ONE_WEEK_STAKING_PERIOD);
        supportedStakingPeriods.add(TWO_WEEKS_STAKING_PERIOD);
        supportedStakingPeriods.add(MAX_STAKING_PERIOD);
    }

    /**
     * @dev Function to allow users to stake tokens with a specific staking period
     * @param amount Amount of tokens to stake
     * @param stakingPeriod Desired staking period identifier
     */
    function stake(uint256 amount, uint256 stakingPeriod) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(supportedStakingPeriods.contains(stakingPeriod), "Invalid staking period");
        
        updateReward(msg.sender);
        
        stakingToken.transferFrom(msg.sender, address(this), amount);
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTimestamp[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount, stakingPeriod);
    }

    /**
     * @dev Function to allow users to withdraw their staked tokens
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        updateReward(msg.sender);

        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        stakingToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Function to allow users to claim rewards based on their staking duration
     */
    function claimReward() external nonReentrant {
        updateReward(msg.sender);
        uint256 reward = calculateReward(msg.sender);

        if (reward > 0) {
            stakingToken.transfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }

    /**
     * @dev Function to update the reward balance of a user based on elapsed time
     * @param account User's 
     */
    function updateReward(address account) internal {
        // Function logic that involves using 'account'
        // ...

        if (block.timestamp > lastRewardTimestamp) {
            uint256 elapsedSeconds = block.timestamp - lastRewardTimestamp;
            uint256 reward = totalStaked * elapsedSeconds * rewardRate;

            stakingToken.transferFrom(owner(), address(this), reward);
            lastRewardTimestamp = block.timestamp;
        }
    }

    /**
     * @dev Function to calculate the pending reward for a user
     * @param account User's address
     * @return Pending reward amount
     */
    function calculateReward(address account) public view returns (uint256) {
        uint256 elapsedSeconds = block.timestamp - lastStakeTimestamp[account];
        return stakedBalances[account] * elapsedSeconds * rewardRate;
    }
}
