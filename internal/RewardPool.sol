// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

// staking reward is from the owner of this contract
contract RewardPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _manager;
    function manager() public view returns (address) { return _manager; }
    modifier onlyManager() {
        require(msg.sender == _manager, "only manager");
        _;
    }

    struct UserInfo {
        uint256 stake;
        uint256 punish;
        uint256 rewardBalance;
        uint256 rewardDebt;
    }
    mapping (address => UserInfo) private _userInfo;

    uint256 public totalStake;
    uint256 public rewardPerBlock;
    uint256 public rewardStartBlock;
    uint256 public lastRewardBlock;
    uint256 private _accRewardPerShare;
    uint256 public punishAmountPerHour;

    event AddStake(address indexed user, uint256 indexed amount);
    event SubStake(address indexed user, uint256 indexed amount);
    event TakeReward(address indexed user, uint256 indexed amount);
    event AddPunish(address indexed user, uint256 indexed offlineHours, uint256 indexed amount);
    event PunishFromReward(address indexed user, uint256 indexed amount);

    constructor(
        address _stakeContract,
        uint256 _rewardPerBlock,
        uint256 _rewardStartBlock
    ) public {
        require(_stakeContract != address(0), "ctor: zero stake contract");
        require(_rewardPerBlock > 1e6, "ctor: reward per block is too small");
        _manager = _stakeContract;
        rewardPerBlock = _rewardPerBlock;
        rewardStartBlock = _rewardStartBlock;
        lastRewardBlock = block.number > rewardStartBlock ? block.number : rewardStartBlock;
    }

    function userInfo(address _user) public view returns (uint256 stakeAmount, uint256 punishAmount) {
        UserInfo storage user = _userInfo[_user];
        stakeAmount = user.stake;
        punishAmount = user.punish;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    function setPunishAmountPerHour(uint256 _amount) public onlyOwner {
        punishAmountPerHour = _amount;
    }

    function accRewardPerShare() public view returns (uint256) {
        if (block.number <= lastRewardBlock || totalStake == 0 || rewardPerBlock == 0) {
            return _accRewardPerShare;
        }
        uint256 multiplier = block.number.sub(lastRewardBlock);
        uint256 tokenReward = multiplier.mul(rewardPerBlock);
        return _accRewardPerShare.add(tokenReward.mul(1e12).div(totalStake));
    }

    function pendingReward(address _user) external view returns (uint256) {
        UserInfo storage user = _userInfo[_user];
        uint256 reward = user.stake.mul(accRewardPerShare()).div(1e12);
        uint256 pending = 0;
        if (reward > user.rewardDebt) {
            pending = reward.sub(user.rewardDebt);
        }
        return user.rewardBalance.add(pending);
    }

    function updatePool() public {
        if (block.number > lastRewardBlock) {
            _accRewardPerShare = accRewardPerShare();
            lastRewardBlock = block.number;
        }
    }

    function _farm(address _user) internal {
        updatePool();
        UserInfo storage user = _userInfo[_user];
        if (user.stake > 0) {
            uint256 reward = user.stake.mul(_accRewardPerShare).div(1e12);
            if (reward > user.rewardDebt) {
                uint256 pending = reward.sub(user.rewardDebt);
                user.rewardBalance = user.rewardBalance.add(pending);
            }
        }
        if (user.punish > 0 && user.rewardBalance > 0) {
            if (user.rewardBalance >= user.punish) {
                emit PunishFromReward(_user, user.punish);
                user.rewardBalance = user.rewardBalance.sub(user.punish);
                user.punish = 0;
            } else {
                emit PunishFromReward(_user, user.rewardBalance);
                user.punish = user.punish.sub(user.rewardBalance);
                user.rewardBalance = 0;
            }
        }
    }

    function takeReward(address _user) public onlyManager returns (uint256 reward) {
        _farm(_user);
        UserInfo storage user = _userInfo[_user];
        reward = user.rewardBalance;
        user.rewardBalance = 0;
        user.rewardDebt = user.stake.mul(_accRewardPerShare).div(1e12);
        emit TakeReward(_user, reward);
    }

    function addStake(address _user, uint256 _amount) public onlyManager {
        require(_amount > 0, "zero amount");
        _farm(_user);
        UserInfo storage user = _userInfo[_user];
        totalStake = totalStake.add(_amount);
        user.stake = user.stake.add(_amount);
        user.rewardDebt = user.stake.mul(_accRewardPerShare).div(1e12);
        emit AddStake(_user, _amount);
    }

    function subStake(address _user, uint256 _amount) public onlyManager {
        require(_amount > 0, "zero amount");
        _farm(_user);
        UserInfo storage user = _userInfo[_user];
        totalStake = totalStake.sub(_amount);
        user.stake = user.stake.sub(_amount);
        user.rewardDebt = user.stake.mul(_accRewardPerShare).div(1e12);
        emit SubStake(_user, _amount);
    }

    function punish(address _user, uint256 _offlineHours) public onlyManager {
        require(punishAmountPerHour > 0, "no punish");
        require(_offlineHours > 0, "zero time");
        UserInfo storage user = _userInfo[_user];
        require(user.stake > 0, "no stake");
        uint256 punishAmount = punishAmountPerHour.mul(_offlineHours);
        user.punish = user.punish.add(punishAmount);
        emit AddPunish(_user, _offlineHours, punishAmount);
    }
}
