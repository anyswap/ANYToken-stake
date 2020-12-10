// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

interface IRewardPool {
    function addStake(address _user, uint256 _amount) external;
    function subStake(address _user, uint256 _amount) external;
    function punish(address _user, uint256 _offlineHours) external;
    function takeReward(address _user) external returns (uint256 _reward);
    function pendingReward(address _user) external view returns (uint256 _reward);
    function userInfo(address _user) external view returns (uint256 _stake, uint256 _punish);
    function manager() external view returns (address);
}

contract NodeStake is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public manager;
    modifier onlyManager() {
        require(msg.sender == manager, "only manager");
        _;
    }

    mapping (address => uint256) public stakeAmount;
    mapping (address => string) public nodeID;

    struct UnstakeInfo {
        bool banned;
        uint256 requestUnstakeAmount;
        uint256 requestUnstakeTime;
        uint256 rejectUnstakeTime;
    }
    mapping (address => UnstakeInfo) private _unstakeInfo;

    uint8 public constant NODETYPE_UNAUTH = 0;
    uint8 public constant NODETYPE_AUTH = 1;
    uint8 public constant NODETYPE_VOTED = 2;
    uint8 public constant NODETYPE_MAX = 2;
    modifier validNodeType(uint8 nodeType) {
        require(nodeType <= NODETYPE_MAX, "invalid node type");
        _;
    }
    struct NodeInfo {
        uint8 nodeType;
        address owner;
    }
    mapping (string => NodeInfo) private _nodeInfo;
    mapping (uint8 => IRewardPool) public rewardPools;

    IERC20 public stakeToken; // ANY token with decimals 18
    uint256 public stakePieceAmount = 5*1e21;
    uint256 public stakeCycleStartTime;
    uint256 public stakeCycleInterval = 30*24*3600;
    uint256 public stakeFreeInterval = 7*24*3600;
    uint256 public unstakeRequestInterval = 3*24*3600;

    event Stake(address indexed user, uint256 indexed amount);
    event Unstake(address indexed user, uint256 indexed amount);
    event RegisterNode(address indexed user, string nodeID);
    event RequestUnstake(address indexed user, uint256 indexed amount, uint256 indexed timestamp);
    event RejectUnstake(address indexed user, uint256 indexed timestamp);
    event AllowUnstake(address indexed user, uint256 indexed timestamp);
    event BanUnstake(address indexed user, bool indexed banned);
    event PunishFromStake(address indexed user, uint256 indexed amount);
    event SetNodeType(uint8 indexed oldType, uint8 indexed newType, string nodeID);
    event SetManager(address indexed oldManager, address indexed newManager);

    constructor(
        IERC20 _stakeToken,
        uint256 _stakeCycleStartTime,
        uint256 _stakePieceAmount
    ) public {
        require(_stakeCycleStartTime + stakeCycleInterval > block.timestamp, "ctor: outdated cycle");
        stakeToken = _stakeToken;
        stakeCycleStartTime =  _stakeCycleStartTime;
        if (_stakePieceAmount > 0) {
            stakePieceAmount = _stakePieceAmount;
        }
        manager = msg.sender;
        emit SetManager(address(0), manager);
    }

    function nodeType(address _user) public view returns (uint8) {
        return _nodeInfo[nodeID[_user]].nodeType;
    }

    function nodeInfo(string memory _nodeID) public view returns (uint8 nodeT, address owner) {
        NodeInfo storage ndInf = _nodeInfo[_nodeID];
        nodeT = ndInf.nodeType;
        owner = ndInf.owner;
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

    function currentCycleInfo() public view returns (uint256 start, uint256 end, bool locked) {
        start = stakeCycleStartTime;
        while (block.timestamp > start.add(stakeCycleInterval)) {
            start = start.add(stakeCycleInterval);
        }
        end = start.add(stakeCycleInterval);
        locked = block.timestamp > start.add(stakeFreeInterval);
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

    function setRewardPool(uint8 _nodeType, IRewardPool _rewardPool) public onlyOwner validNodeType(_nodeType) {
        require(address(rewardPools[_nodeType]) == address(0), "pool exist");
        require(_rewardPool.manager() == address(this), "not match");
        rewardPools[_nodeType] = _rewardPool;
    }

    function setUnstakeRequestInterval(uint256 _interval) public onlyOwner {
        unstakeRequestInterval = _interval;
    }

    function updateStakeCycle() public {
        while (block.timestamp > stakeCycleStartTime.add(stakeCycleInterval)) {
            stakeCycleStartTime = stakeCycleStartTime.add(stakeCycleInterval);
        }
    }

    function stake(uint256 _amount) public {
        require(_amount > 0 && _amount.mod(stakePieceAmount) == 0, "wrong stake amount");
        updateStakeCycle();
        stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        uint256 newStake = stakeAmount[msg.sender].add(_amount);
        stakeAmount[msg.sender] = newStake;
        IRewardPool pool = rewardPools[nodeType(msg.sender)];
        if (address(pool) != address(0)) {
            pool.addStake(msg.sender, _amount);
        }
        emit Stake(msg.sender, _amount);
    }

    function requestUnstake(uint256 _amount) public {
        require(_amount > 0 && _amount.mod(stakePieceAmount) == 0, "wrong unstake amount");
        updateStakeCycle();
        require(block.timestamp > stakeCycleStartTime &&
                block.timestamp <= stakeCycleStartTime.add(stakeFreeInterval), "is locked");
        require(stakeAmount[msg.sender] >= _amount, "not enough stake");
        UnstakeInfo storage unstake = _unstakeInfo[msg.sender];
        unstake.requestUnstakeAmount = _amount;
        unstake.requestUnstakeTime = block.timestamp;
        emit RequestUnstake(msg.sender, _amount, block.timestamp);
    }

    function rejectUnstake(address _user) public onlyManager {
        updateStakeCycle();
        UnstakeInfo storage unstake = _unstakeInfo[_user];
        if (unstake.requestUnstakeTime > stakeCycleStartTime) {
            unstake.rejectUnstakeTime = block.timestamp;
            emit RejectUnstake(_user, block.timestamp);
        }
    }

    function allowUnstake(address _user) public onlyManager {
        updateStakeCycle();
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
        return _canUnstake(_user, _unstakeInfo[_user], _amount);
    }

    function _canUnstake(address _user, UnstakeInfo storage _unstake, uint256 _amount) internal view returns (bool) {
        // unstake amount must be nonzero and integral part of piece amount
        if (_amount == 0 || _amount.mod(stakePieceAmount) != 0) {
            return false;
        }
        // not enough stake amount
        if (stakeAmount[_user] < _amount) {
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
        updateStakeCycle();
        UnstakeInfo storage unstakes = _unstakeInfo[msg.sender];
        require(_canUnstake(msg.sender, unstakes, _amount), "can not unstake");
        bool isUnstakeAll = _amount == stakeAmount[msg.sender];
        uint256 punishAmount = 0;
        IRewardPool pool = rewardPools[nodeType(msg.sender)];
        if (address(pool) != address(0)) {
            pool.subStake(msg.sender, _amount);
            if (isUnstakeAll) {
                (, punishAmount) = pool.userInfo(msg.sender);
            }
        }
        if (isUnstakeAll) {
            // settlement of punish
            if (punishAmount > 0) {
                if (_amount >= punishAmount) {
                    emit PunishFromStake(msg.sender, punishAmount);
                    _amount = _amount.sub(punishAmount);
                } else {
                    emit PunishFromStake(msg.sender, _amount);
                    _amount = 0;
                }
            }
            // clearing of storage
            delete _nodeInfo[nodeID[msg.sender]];
            delete _unstakeInfo[msg.sender];
            stakeAmount[msg.sender] = 0;
            nodeID[msg.sender] = "";
        } else {
            uint256 newStake = stakeAmount[msg.sender].sub(_amount);
            stakeAmount[msg.sender] = newStake;
            unstakes.requestUnstakeAmount = unstakes.requestUnstakeAmount.sub(_amount);
        }
        if (_amount > 0) {
            stakeToken.safeTransfer(address(msg.sender), _amount);
        }
        emit Unstake(msg.sender, _amount);
    }

    function registerNode(string memory _nodeID) public {
        require(bytes(_nodeID).length > 0 && bytes(_nodeID).length <= 256, "invalid nodeID");
        require(_nodeInfo[_nodeID].owner == address(0), "already registered");
        require(stakeAmount[msg.sender] > 0, "no stake");
        delete _nodeInfo[nodeID[msg.sender]];
        NodeInfo storage ndInf = _nodeInfo[_nodeID];
        ndInf.nodeType = NODETYPE_UNAUTH;
        ndInf.owner = msg.sender;
        nodeID[msg.sender] = _nodeID;
        emit RegisterNode(msg.sender, _nodeID);
    }

    function setNodeType(string memory _nodeID, uint8 _nodeType) public onlyManager validNodeType(_nodeType) {
        NodeInfo storage ndInf = _nodeInfo[_nodeID];
        require(ndInf.owner != address(0), "not register");
        require(ndInf.nodeType != _nodeType, "same node type");
        uint256 amount = stakeAmount[ndInf.owner];
        if (amount > 0) {
            IRewardPool oldPool = rewardPools[ndInf.nodeType];
            IRewardPool newPool = rewardPools[_nodeType];
            if (address(oldPool) != address(0)) {
                _sendReward(ndInf.owner, oldPool.takeReward(ndInf.owner));
                oldPool.subStake(ndInf.owner, amount);
            }
            if (address(newPool) != address(0)) {
                newPool.addStake(ndInf.owner, amount);
            }
        }
        emit SetNodeType(ndInf.nodeType, _nodeType, _nodeID);
        ndInf.nodeType = _nodeType;
    }

    function _sendReward(address _user, uint256 _reward) internal {
        if (_reward > 0) {
            stakeToken.safeTransferFrom(owner(), _user, _reward);
        }
    }

    function takeReward() public {
        IRewardPool pool = rewardPools[nodeType(msg.sender)];
        if (address(pool) != address(0)) {
            _sendReward(msg.sender, pool.takeReward(msg.sender));
        }
    }

    function punish(address _user, uint256 _offlineHours) public onlyManager {
        IRewardPool pool = rewardPools[nodeType(_user)];
        if (address(pool) != address(0)) {
            pool.punish(_user, _offlineHours);
        }
    }

    function userInfo(address _user) public view returns (uint256 _stake, uint256 _punish) {
        IRewardPool pool = rewardPools[nodeType(_user)];
        if (address(pool) != address(0)) {
            (_stake, _punish) = pool.userInfo(_user);
        }
    }

    function pendingReward(address _user) public view returns (uint256 reward) {
        IRewardPool pool = rewardPools[nodeType(_user)];
        if (address(pool) != address(0)) {
            reward = pool.pendingReward(_user);
        }
    }
}
