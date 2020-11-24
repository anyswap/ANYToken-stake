// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

// ANY staking smart contract
// staking reward is from the owner of this contract
contract Stake is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        string nodeID;
    }
    mapping (address => UserInfo) public userInfo;

    uint256 public lastRewardBlock;  // Last block number that Rewards distribution occurs.
    uint256 public accRewardPerShare; // Accumulated Rewards per share, times 1e12.

    IERC20 public stakeToken;
    uint256 public rewardPerBlock;
    uint256 public rewardStartBlock;

    event Deposit(address indexed user, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed amount);
    event RegisterNode(address indexed user, string nodeID);

    constructor(
        IERC20 _stakeToken,
        uint256 _rewardPerBlock,
        uint256 _rewardStartBlock
    ) public {
        require(_rewardPerBlock > 1e6, "ctor: reward per block is too small");
        stakeToken = _stakeToken;
        rewardPerBlock = _rewardPerBlock;
        rewardStartBlock = _rewardStartBlock;

        lastRewardBlock = block.number > rewardStartBlock ? block.number : rewardStartBlock;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    function calcAccRewardPerShare() public view returns (uint256) {
        if (block.number <= lastRewardBlock) {
            return accRewardPerShare;
        }
        uint256 lpSupply = stakeToken.balanceOf(address(this));
        if (lpSupply == 0) {
            return accRewardPerShare;
        }
        uint256 multiplier = block.number.sub(lastRewardBlock);
        uint256 tokenReward = multiplier.mul(rewardPerBlock);
        if (tokenReward <= 0) {
            return accRewardPerShare;
        }
        return accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
    }

    // View function to see pending REWARDs on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        uint256 newAccRewardPerShare = calcAccRewardPerShare();
        UserInfo storage user = userInfo[_user];
        uint256 reward = user.amount.mul(newAccRewardPerShare).div(1e12);
        if (reward > user.rewardDebt) {
            return reward.sub(user.rewardDebt);
        }
        return 0;
    }

    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        accRewardPerShare = calcAccRewardPerShare();
        lastRewardBlock = block.number;
    }

    function farm(UserInfo storage user) internal {
        updatePool();
        if (user.amount > 0) {
            uint256 reward = user.amount.mul(accRewardPerShare).div(1e12);
            if (reward > user.rewardDebt) {
                uint256 pending = reward.sub(user.rewardDebt);
                stakeToken.safeTransferFrom(owner(), address(msg.sender), pending);
            }
        }
    }

    // Deposit stake tokens
    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        farm(user);
        if (_amount > 0) {
            stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw stake tokens
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "not enough balance");
        farm(user);
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            stakeToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        stakeToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    // Register node. must have stake
    function registerNode(string memory _nodeID) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "no stake");
        user.nodeID = _nodeID;
        emit RegisterNode(msg.sender, _nodeID);
    }
}
