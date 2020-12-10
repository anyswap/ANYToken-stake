// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through `transferFrom`. This is
     * zero by default.
     *
     * This value changes when `approve` or `transferFrom` are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * > Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an `Approval` event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a `Transfer` event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to `approve`. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: @openzeppelin/contracts/math/SafeMath.sol

pragma solidity ^0.5.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

// File: @openzeppelin/contracts/utils/Address.sol

pragma solidity ^0.5.0;

/**
 * @dev Collection of functions related to the address type,
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * This test is non-exhaustive, and there may be false-negatives: during the
     * execution of a contract's constructor, its address will be reported as
     * not containing a contract.
     *
     * > It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol

pragma solidity ^0.5.0;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: @openzeppelin/contracts/ownership/Ownable.sol

pragma solidity ^0.5.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be aplied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * > Note: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: internal/NodeStake.sol

pragma solidity ^0.5.0;





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
