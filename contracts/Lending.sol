// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
/**
 * @title Borrowing and Lending Smart Contract
 */
contract LendingPlatform is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ERC20 token being used for lending
    IERC20 public token;

    // Mapping to track borrowed amounts
    mapping(address => uint256) public borrowedAmounts;

    // Interest rate parameters (in basis points)
    uint256 public baseInterestRate; // Base interest rate
    uint256 public interestRatePerDuration; // Interest rate per second
    uint256 public minDuration; // Minimum borrowing duration in seconds

    // Events
    event Borrow(address indexed borrower, uint256 amount, uint256 interest, uint256 duration);
    event Repay(address indexed borrower, uint256 amount);

    /**
     * @dev Constructor to initialize the lending platform
     * @param _tokenAddress Address of the ERC20 token used for lending
     * @param _baseInterestRate Base interest rate in basis points (1% = 100)
     * @param _interestRatePerDuration Interest rate per second
     * @param _minDuration Minimum borrowing duration in seconds
     */
    constructor(
        address _tokenAddress,
        uint256 _baseInterestRate,
        uint256 _interestRatePerDuration,
        uint256 _minDuration  
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        require(_baseInterestRate > 0, "Base interest rate must be greater than zero");
        require(_interestRatePerDuration > 0, "Interest rate per duration must be greater than zero");
        require(_minDuration > 0, "Minimum duration must be greater than zero");

        token = IERC20(_tokenAddress);
        baseInterestRate = _baseInterestRate;
        interestRatePerDuration = _interestRatePerDuration;
        minDuration = _minDuration;
    }

    /**
     * @dev Function to borrow funds
     * @param _amount The amount to borrow
     * @param _duration The borrowing duration in seconds
     */
    function borrow(uint256 _amount, uint256 _duration) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");
        require(_duration >= minDuration, "Duration below minimum allowed");

        // Calculate interest
        uint256 interest = calculateInterest(_amount, _duration);

        // Ensure user has enough balance to cover the loan and interest
        require(token.balanceOf(msg.sender) >= _amount.add(interest), "Insufficient balance");

        // Transfer funds to the borrower
        token.safeTransferFrom(msg.sender, address(this), _amount.add(interest));

        // Update borrowed amounts
        borrowedAmounts[msg.sender] = borrowedAmounts[msg.sender].add(_amount);

        // Emit event
        emit Borrow(msg.sender, _amount, interest, _duration);
    }

    /**
     * @dev Function to repay borrowed funds
     * @param _amount The amount to repay
     */
    function repay(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than zero");

        // Ensure user has enough balance to cover the repayment
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");

        // Transfer funds from the borrower to the contract
        token.safeTransferFrom(msg.sender, address(this), _amount);

        // Update borrowed amounts
        borrowedAmounts[msg.sender] = borrowedAmounts[msg.sender].sub(_amount);
        //@audit check for if else argument.
        

        // Emit event
        emit Repay(msg.sender, _amount);
    }

    /**
     * @dev Function to calculate interest based on the borrowing amount and duration
     * @param _amount The borrowing amount
     * @param _duration The borrowing duration in seconds
     * @return The calculated interest amount
     */
    function calculateInterest(uint256 _amount, uint256 _duration) public view returns (uint256) {
        uint256 totalInterest = _amount.mul(baseInterestRate).div(10000); // Base interest

        // Additional interest based on duration
        uint256 durationInterest = _amount.mul(interestRatePerDuration).mul(_duration).div(1e18);

        return totalInterest.add(durationInterest);
    }

    /**
     * @dev Function to withdraw excess funds from the contract by the owner
     * @param _amount The amount to withdraw
     */
    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Withdrawal amount must be greater than zero");
        require(_amount <= token.balanceOf(address(this)), "Insufficient funds in the contract");

        token.safeTransfer(owner(), _amount);
    }
}
