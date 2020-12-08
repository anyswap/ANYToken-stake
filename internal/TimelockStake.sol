// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

interface IStake {
    function stakeToken() external view returns (IERC20);
    function userInfo(address _user) external view returns (uint256 stake, uint256 punish, string memory nodeID);
    function upper() external view returns (IStake);
    function lower() external view returns (IStake);
    function stake(uint256 _amount) external;
    function unstake(uint256 _amount) external;
    function importStake(address _user, bool _fromLower) external;
}

// ANY time lock staking smart contract
// staking reward is from the owner of this contract
contract TimelockStake is Ownable, IStake {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IStake private _upperContract;
    IStake private _lowerContract;
    address public manager;
    modifier onlyManager() {
        require(msg.sender == manager, "only manager");
        _;
    }

    struct UserInfo {
        uint256 stake;
        uint256 punish;
        uint256 rewardBalance;
        uint256 rewardDebt;
        string nodeID;
    }
    mapping (address => UserInfo) private _userInfo;

    struct UnstakeInfo {
        bool banned;
        uint256 requestUnstakeAmount;
        uint256 requestUnstakeTime;
        uint256 rejectUnstakeTime;
    }
    mapping (address => UnstakeInfo) private _unstakeInfo;

    struct NodeInfo {
        address owner;
        uint256 registerTime;
    }
    mapping (string => NodeInfo) private _nodeInfo;

    uint256 public rewardPerBlock;
    uint256 public rewardStartBlock;
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;

    IERC20 private _stakeToken; // ANY token with decimals 18
    uint256 public stakePieceAmount = 5*1e21;
    uint256 public stakeCycleStartTime;
    uint256 public stakeCycleInterval = 30*24*3600;
    uint256 public stakeFreeInterval = 7*24*3600;
    uint256 public unstakeRequestInterval = 3*24*3600;
    uint256 public punishAmountPerHour;

    event Stake(address indexed user, uint256 indexed amount);
    event Unstake(address indexed user, uint256 indexed amount);
    event TakeReward(address indexed user, uint256 indexed amount);
    event RegisterNode(address indexed user, string nodeID);
    event RequestUnstake(address indexed user, uint256 indexed amount, uint256 indexed timestamp);
    event RejectUnstake(address indexed user, uint256 indexed timestamp);
    event AllowUnstake(address indexed user, uint256 indexed timestamp);
    event BanUnstake(address indexed user, bool indexed banned);
    event AddPunish(address indexed user, uint256 indexed offlineHours, uint256 indexed amount);
    event PunishFromReward(address indexed user, uint256 indexed amount);
    event PunishFromStake(address indexed user, uint256 indexed amount);
    event UpgradeNode(address indexed from, address indexed to, string nodeID);
    event DowngradeNode(address indexed from, address indexed to, string nodeID);
    event SetManager(address indexed oldManager, address indexed newManager);

    constructor(
        IERC20 _stakeTokenAddr,
        uint256 _rewardPerBlock,
        uint256 _rewardStartBlock,
        uint256 _stakeCycleStartTime,
        uint256 _stakePieceAmount
    ) public {
        require(_rewardPerBlock == 0 || _rewardPerBlock > 1e6, "ctor: reward per block is too small");
        require(_stakeCycleStartTime + stakeCycleInterval > block.timestamp, "ctor: outdated cycle");

        _stakeToken = _stakeTokenAddr;
        rewardPerBlock = _rewardPerBlock;
        rewardStartBlock = _rewardStartBlock;
        stakeCycleStartTime =  _stakeCycleStartTime;
        if (_stakePieceAmount > 0) {
            stakePieceAmount = _stakePieceAmount;
        }

        lastRewardBlock = block.number > rewardStartBlock ? block.number : rewardStartBlock;

        manager = msg.sender;
        emit SetManager(address(0), manager);
    }

    function stakeToken() public view returns (IERC20) {
        return _stakeToken;
    }

    function upper() public view returns (IStake) {
        return _upperContract;
    }

    function lower() public view returns (IStake) {
        return _lowerContract;
    }

    function userInfo(address _user) public view returns (uint256 stakeAmount, uint256 punishAmount, string memory nodeID) {
        UserInfo storage user = _userInfo[_user];
        stakeAmount = user.stake;
        punishAmount = user.punish;
        nodeID = user.nodeID;
    }

    function unstakeInfo(address _user) public view returns (uint256 amount, bool allowed, bool rejected) {
        uint256 currCycleStart = stakeCycleStartTime;
        while (block.timestamp > currCycleStart.add(stakeCycleInterval)) {
            currCycleStart = currCycleStart.add(stakeCycleInterval);
        }
        UnstakeInfo storage unstake = _unstakeInfo[_user];
        if (unstake.requestUnstakeTime > currCycleStart) {
            amount = unstake.requestUnstakeAmount;
            allowed = unstake.rejectUnstakeTime == currCycleStart;
            rejected = unstake.rejectUnstakeTime > currCycleStart;
        }
    }

    function nodeInfo(string memory _nodeID) public view returns (address owner, uint256 registerTime) {
        NodeInfo storage nodes = _nodeInfo[_nodeID];
        owner = nodes.owner;
        registerTime = nodes.registerTime;
    }

    function currentCycleInfo() public view returns (uint256 start, uint256 end, bool locked) {
        start = stakeCycleStartTime;
        while (block.timestamp > start.add(stakeCycleInterval)) {
            start = start.add(stakeCycleInterval);
        }
        end = start.add(stakeCycleInterval);
        locked = block.timestamp > start.add(stakeFreeInterval);
    }

    function setUpper(IStake _upper) public onlyOwner {
        require(address(_upper) == address(0) || _upper.stakeToken() == _stakeToken, "invalid stake token");
        _upperContract = _upper;
    }

    function setLower(IStake _lower) public onlyOwner {
        require(address(_lower) == address(0) || _lower.stakeToken() == _stakeToken, "invalid stake token");
        _lowerContract = _lower;
    }

    function setManager(address _manager) public onlyOwner {
        emit SetManager(manager, _manager);
        manager = _manager;
    }

    function setStakeCycle(uint256 _startTime, uint256 _cycleInterval, uint256 _freeInterval) public onlyOwner {
        require(_cycleInterval >= _freeInterval, "wrong interval");
        require(_startTime.add(_cycleInterval) > block.timestamp, "outdated cycle");
        stakeCycleStartTime = _startTime;
        stakeCycleInterval = _cycleInterval;
        stakeFreeInterval = _freeInterval;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    function setUnstakeRequestInterval(uint256 _interval) public onlyOwner {
        unstakeRequestInterval = _interval;
    }

    function setPunishAmountPerHour(uint256 _amount) public onlyOwner {
        punishAmountPerHour = _amount;
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

    function calcAccRewardPerShare() public view returns (uint256) {
        if (block.number <= lastRewardBlock) {
            return accRewardPerShare;
        }
        uint256 lpSupply = _stakeToken.balanceOf(address(this));
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

    function pendingReward(address _user) external view returns (uint256) {
        uint256 newAccRewardPerShare = calcAccRewardPerShare();
        UserInfo storage user = _userInfo[_user];
        uint256 reward = user.stake.mul(newAccRewardPerShare).div(1e12);
        uint256 pending = 0;
        if (reward > user.rewardDebt) {
            pending = reward.sub(user.rewardDebt);
        }
        return user.rewardBalance.add(pending);
    }

    function _updateStakeCycle() internal {
        while (block.timestamp > stakeCycleStartTime.add(stakeCycleInterval)) {
            stakeCycleStartTime = stakeCycleStartTime.add(stakeCycleInterval);
        }
    }

    function updatePool() public {
        _updateStakeCycle();
        if (block.number > lastRewardBlock) {
            accRewardPerShare = calcAccRewardPerShare();
            lastRewardBlock = block.number;
        }
    }

    function _farm(UserInfo storage user) internal {
        updatePool();
        if (user.stake > 0) {
            uint256 reward = user.stake.mul(accRewardPerShare).div(1e12);
            if (reward > user.rewardDebt) {
                uint256 pending = reward.sub(user.rewardDebt);
                user.rewardBalance = user.rewardBalance.add(pending);
            }
        }
        if (user.punish > 0 && user.rewardBalance > 0) {
            if (user.rewardBalance >= user.punish) {
                emit PunishFromReward(msg.sender, user.punish);
                user.rewardBalance = user.rewardBalance.sub(user.punish);
                user.punish = 0;
            } else {
                emit PunishFromReward(msg.sender, user.rewardBalance);
                user.punish = user.punish.sub(user.rewardBalance);
                user.rewardBalance = 0;
            }
        }
    }

    function takeReward() public {
        UserInfo storage user = _userInfo[msg.sender];
        _farm(user);
        uint256 reward = user.rewardBalance;
        if (reward > 0) {
            user.rewardBalance = 0;
            _stakeToken.safeTransferFrom(owner(), address(msg.sender), reward);
        }
        user.rewardDebt = user.stake.mul(accRewardPerShare).div(1e12);
        emit TakeReward(msg.sender, reward);
    }

    function stake(uint256 _amount) public {
        require(_amount > 0 && _amount.mod(stakePieceAmount) == 0, "wrong stake amount");
        UserInfo storage user = _userInfo[msg.sender];
        require(user.stake > 0 || address(_lowerContract) == address(0), "can not stake");
        _farm(user);
        _stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.stake = user.stake.add(_amount);
        user.rewardDebt = user.stake.mul(accRewardPerShare).div(1e12);
        emit Stake(msg.sender, _amount);
    }

    function requestUnstake(uint256 _amount) public {
        require(_amount > 0 && _amount.mod(stakePieceAmount) == 0, "wrong unstake amount");
        _updateStakeCycle();
        require(block.timestamp > stakeCycleStartTime &&
                block.timestamp <= stakeCycleStartTime.add(stakeFreeInterval), "is locked");
        UserInfo storage user = _userInfo[msg.sender];
        require(user.stake >= _amount, "not enough stake");
        UnstakeInfo storage unstake = _unstakeInfo[msg.sender];
        unstake.requestUnstakeAmount = _amount;
        unstake.requestUnstakeTime = block.timestamp;
        emit RequestUnstake(msg.sender, _amount, block.timestamp);
    }

    function rejectUnstake(address _user) public onlyManager {
        _updateStakeCycle();
        UnstakeInfo storage unstake = _unstakeInfo[_user];
        if (unstake.requestUnstakeTime > stakeCycleStartTime) {
            unstake.rejectUnstakeTime = block.timestamp;
            emit RejectUnstake(_user, block.timestamp);
        }
    }

    function allowUnstake(address _user) public onlyManager {
        _updateStakeCycle();
        UnstakeInfo storage unstake = _unstakeInfo[_user];
        if (unstake.requestUnstakeTime > stakeCycleStartTime) {
            unstake.rejectUnstakeTime = stakeCycleStartTime;
            emit AllowUnstake(_user, block.timestamp);
        }
    }

    function banUnstake(address _user, bool _banned) public onlyManager {
        UnstakeInfo storage unstake = _unstakeInfo[_user];
        unstake.banned = _banned;
        emit BanUnstake(_user, _banned);
    }

    function isUnstakeBanned(address _user) public view returns (bool) {
        return _unstakeInfo[_user].banned;
    }

    function canUnstake(address _user, uint256 _amount) public view returns (bool) {
        return _canUnstake(_userInfo[_user], _unstakeInfo[_user], _amount);
    }

    function _canUnstake(UserInfo storage _user, UnstakeInfo storage _unstake, uint256 _amount) internal view returns (bool) {
        // unstake amount must be nonzero and integral part of piece amount
        if (_amount == 0 || _amount.mod(stakePieceAmount) != 0) {
            return false;
        }
        // not enough stake amount
        if (_user.stake < _amount) {
            return false;
        }
        // always lock free
        if (stakeCycleInterval == stakeFreeInterval) {
            return true;
        }
        // not enough request amount
        if (_unstake.requestUnstakeAmount < _amount) {
            return false;
        }
        uint256 currCycleStart = stakeCycleStartTime;
        while (block.timestamp > currCycleStart.add(stakeCycleInterval)) {
            currCycleStart = currCycleStart.add(stakeCycleInterval);
        }
        // no request
        if (_unstake.requestUnstakeTime < currCycleStart) {
                return false;
        }
        // request time is too short and not allowed explicitly
        if (block.timestamp < _unstake.requestUnstakeTime.add(unstakeRequestInterval) &&
            _unstake.rejectUnstakeTime != currCycleStart) {
            return false;
        }
        // banned or rejected
        if (_unstake.banned || _unstake.rejectUnstakeTime > currCycleStart) {
            return false;
        }
        return true;
    }

    function unstake(uint256 _amount) public {
        UserInfo storage user = _userInfo[msg.sender];
        _farm(user);
        UnstakeInfo storage unstakes = _unstakeInfo[msg.sender];
        require(_canUnstake(user, unstakes, _amount), "can not unstake");
        bool isUnstakeAll = _amount == user.stake;
        if (isUnstakeAll) {
            // settlement of punish
            if (user.punish > 0) {
                if (_amount >= user.punish) {
                    emit PunishFromStake(msg.sender, user.punish);
                    _amount = _amount.sub(user.punish);
                } else {
                    emit PunishFromStake(msg.sender, _amount);
                    _amount = 0;
                }
            }
            // clearing of storage
            delete _nodeInfo[user.nodeID];
            delete _userInfo[msg.sender];
            delete _unstakeInfo[msg.sender];
        } else {
            user.stake = user.stake.sub(_amount);
            unstakes.requestUnstakeAmount = unstakes.requestUnstakeAmount.sub(_amount);
            user.rewardDebt = user.stake.mul(accRewardPerShare).div(1e12);
        }
        if (_amount > 0) {
            _stakeToken.safeTransfer(address(msg.sender), _amount);
        }
        emit Unstake(msg.sender, _amount);
    }

    function registerNode(string memory _nodeID) public {
        require(address(_lowerContract) == address(0), "can not register");
        require(bytes(_nodeID).length > 0 && bytes(_nodeID).length <= 256, "invalid nodeID");
        NodeInfo storage nodes = _nodeInfo[_nodeID];
        require(nodes.owner == address(0), "already registered");
        UserInfo storage user = _userInfo[msg.sender];
        require(user.stake >= stakePieceAmount, "no stake");
        if (bytes(user.nodeID).length > 0) {
            delete _nodeInfo[user.nodeID]; // delete old
        }
        user.nodeID = _nodeID;
        nodes.owner = msg.sender;
        nodes.registerTime = block.timestamp;
        emit RegisterNode(msg.sender, _nodeID);
    }

    function setNode(address _user, string memory _nodeID) public onlyOwner {
        require(bytes(_nodeID).length > 0 && bytes(_nodeID).length <= 256, "invalid nodeID");
        NodeInfo storage nodes = _nodeInfo[_nodeID];
        UserInfo storage user = _userInfo[_user];
        require(user.stake > 0, "no stake");
        if (bytes(user.nodeID).length > 0) {
            delete _nodeInfo[user.nodeID]; // delete old
        }
        user.nodeID = _nodeID;
        nodes.owner = _user;
        nodes.registerTime = block.timestamp;
        emit RegisterNode(_user, _nodeID);
    }

    function importStake(address _user, bool _fromLower) public {
        UserInfo storage user = _userInfo[_user];
        require(user.stake == 0 && bytes(user.nodeID).length == 0, "already exist");
        require((_fromLower && _lowerContract.upper() == IStake(this)) ||
                (!_fromLower && _upperContract.lower() == IStake(this)), "not linked");
        IStake from = _fromLower ? _lowerContract : _upperContract;
        require(msg.sender == address(from), "wrong caller");
        (uint256 stakeAmount, uint256 punishAmount, string memory nodeID) = from.userInfo(_user);
        user.stake = stakeAmount;
        user.punish = punishAmount;
        user.nodeID = nodeID;
        NodeInfo storage nodes = _nodeInfo[nodeID];
        require(nodes.owner == address(0) || nodes.registerTime == 1, "already exist");
        nodes.owner = _user;
        nodes.registerTime = block.timestamp;
        updatePool();
        user.rewardDebt = user.stake.mul(accRewardPerShare).div(1e12);
    }

    function upgradeNode(string memory _nodeID) public onlyManager {
        require(address(_upperContract) != address(0) && _upperContract.lower() == IStake(this), "not linked");
        migrateNode(_nodeID, true);
        emit UpgradeNode(address(this), address(_upperContract), _nodeID);
    }

    function downgradeNode(string memory _nodeID) public onlyManager {
        require(address(_lowerContract) != address(0) && _lowerContract.upper() == IStake(this), "not linked");
        migrateNode(_nodeID, false);
        emit DowngradeNode(address(this), address(_lowerContract), _nodeID);
    }

    function migrateNode(string memory _nodeID, bool _upgrade) internal {
        NodeInfo storage nodes = _nodeInfo[_nodeID];
        require(nodes.owner != address(0), "not registered");
        UserInfo storage user = _userInfo[nodes.owner];
        require(user.stake > 0, "no stake");

        _farm(user);
        IStake to = _upgrade ? _upperContract : _lowerContract;
        to.importStake(nodes.owner, !_upgrade);
        _stakeToken.safeTransfer(address(to), user.stake);

        // clearing of storage
        user.stake = 0;
        user.punish = 0;
        user.rewardDebt = 0;
        delete _unstakeInfo[msg.sender];
        if (address(_lowerContract) == address(0)) {
            _nodeInfo[_nodeID].registerTime = 1; // set upgrade flag
        } else {
            delete _nodeInfo[_nodeID];
            user.nodeID = "";
        }
    }
}
