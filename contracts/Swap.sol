// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.8.21;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Token is ERC20, ERC20Mintable {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // You don't need to override the mint function; it's already implemented in ERC20Mintable.
    // You don't need to write a custom transfer function as it is already imported in the ERC20 contract.
}

contract TokenSwap is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public admin;
    IERC20 public token1;
    IERC20 public token2;

    // Define a fair exchange rate oracle, which is set by the owner
    uint256 public fairExchangeRate;

    event TokensSwapped(address indexed user, uint256 amount1, uint256 amount2);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    constructor(address _admin, address _token1, address _token2, uint256 _fairExchangeRate) {
        admin = _admin;
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);
        fairExchangeRate = _fairExchangeRate;
    }

    function setFairExchangeRate(uint256 _newRate) external onlyOwner {
        fairExchangeRate = _newRate;
    }

    function swapTokens(uint256 amount1, uint256 amount2) external nonReentrant {
        require(token1.balanceOf(msg.sender) >= amount1, "Insufficient balance of token1");

        // Prevent reentrancy attack
        uint256 balanceBefore = token1.balanceOf(msg.sender);
        token1.safeTransferFrom(msg.sender, address(this), amount1);
        require(token1.balanceOf(msg.sender) == balanceBefore - amount1, "Reentrancy attack detected");

        // Ensure fair exchange rate using the oracle
        require(amount2 == (amount1 * fairExchangeRate) / 1e18, "Invalid exchange rate");

        token2.safeTransfer(msg.sender, amount2);

        emit TokensSwapped(msg.sender, amount1, amount2);
    }

    function userWithdraw() external nonReentrant {
        // Allow users to withdraw their tokens
        uint256 userBalance = token2.balanceOf(msg.sender);
        require(userBalance > 0, "No tokens to withdraw");

        token2.safeTransfer(msg.sender, userBalance);
    }

    // Allow anyone to withdraw if there are excess tokens
    function emergencyWithdraw() external nonReentrant {
        uint256 excessBalance = token2.balanceOf(address(this)) - token2.balanceOf(admin);
        require(excessBalance > 0, "No excess tokens to withdraw");

        token2.safeTransfer(admin, excessBalance);
    }
}
