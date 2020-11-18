// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

// ANY staking smart contract
contract Stake is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }
    mapping (address => UserInfo) public userInfo;

    uint256 lastRewardBlock;  // Last block number that Rewards distribution occurs.
    uint256 accRewardPerShare; // Accumulated Rewards per share, times 1e12.

    IERC20 public stakeToken;
    uint256 public rewardPerBlock;
    uint256 public rewardStartBlock;
    uint256 public bonusEndBlock;
    uint256 public constant BONUS_MULTIPLIER = 2;

    event Deposit(address indexed user, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed amount);

    constructor(
        IERC20 _stakeToken,
        uint256 _rewardPerBlock,
        uint256 _rewardStartBlock,
        uint256 _bonusEndBlock
    ) public {
        require(_rewardPerBlock > 1e6, "ctor: reward per block is too small");
        stakeToken = _stakeToken;
        rewardPerBlock = _rewardPerBlock;
        bonusEndBlock = _bonusEndBlock;
        rewardStartBlock = _rewardStartBlock;

        lastRewardBlock = block.number > rewardStartBlock ? block.number : rewardStartBlock;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_from <= _to) {
            return 0;
        } else if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    function calcTokenReward() internal view returns (uint256) {
        if (block.number <= lastRewardBlock) {
            return 0;
        }
        uint256 multiplier = getMultiplier(lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(rewardPerBlock);
        return tokenReward;
    }

    // View function to see pending REWARDs on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        uint256 newAccRewardPerShare = accRewardPerShare;
        UserInfo storage user = userInfo[_user];
        uint256 tokenReward = calcTokenReward();
        if (tokenReward > 0) {
            uint256 lpSupply = stakeToken.balanceOf(address(this));
            newAccRewardPerShare = accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        uint256 pending = user.amount.mul(newAccRewardPerShare).div(1e12);
        if (pending > user.rewardDebt) {
            return pending.sub(user.rewardDebt);
        }
        return 0;
    }

    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        uint256 tokenReward = calcTokenReward();
        if (tokenReward > 0) {
            uint256 lpSupply = stakeToken.balanceOf(address(this));
            accRewardPerShare = accRewardPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        lastRewardBlock = block.number;
    }

    function farm(UserInfo storage user) internal {
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accRewardPerShare).div(1e12);
            if(pending > user.rewardDebt) {
                pending = pending.sub(user.rewardDebt);
                user.amount = user.amount.add(pending);
            }
        }
    }

    // Deposit stake tokens
    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        farm(user);
        if(_amount > 0) {
            stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(accRewardPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw stake tokens
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        farm(user);
        require(user.amount >= _amount, "not enough balance");
        if(_amount > 0) {
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
}
