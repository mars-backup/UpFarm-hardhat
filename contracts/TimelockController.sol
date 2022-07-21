// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IStrategy {

    function earn() external;

    function farm() external;

    function pause() external;

    function unpause() external;

    function wrapBNB() external;
    
}

interface IUpFarm {

    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat,
        bool _locked
    ) external;

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bool _locked
    ) external;

}

contract TimelockController is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    uint256 internal constant _DONE_TIMESTAMP = uint256(1);

    mapping(bytes32 => uint256) private _timestamps;
    uint256 public minDelay;
    uint256 public minDelayReduced;

    /**
     * @dev Emitted when a call is scheduled as part of operation `id`.
     */
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );

    /**
     * @dev Emitted when a call is scheduled as part of operation `id`.
     */
    event SetScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bool _locked,
        bytes32 predecessor,
        uint256 delay
    );

    /**
     * @dev Emitted when a call is executed as part of operation `id`.
     */
    event SetExecuted(
        bytes32 indexed id,
        uint256 indexed index,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bytes32 predecessor
    );

    /**
     * @dev Emitted when a call is performed as part of operation `id`.
     */
    event CallExecuted(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data
    );

    /**
     * @dev Emitted when operation `id` is cancelled.
     */
    event Cancelled(bytes32 indexed id);

    /**
     * @dev Emitted when the minimum delay for future operations is modified.
     */
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    event MinDelayReducedChange(uint256 oldDuration, uint256 newDuration);

    event Add(
        address _autofarmAddress,
        address _want,
        bool _withUpdate,
        address _strat,
        bool _locked
    );

    event Earn(address _stratAddress);
    event Farm(address _stratAddress);
    event Pause(address _stratAddress);
    event UnPause(address _stratAddress);
    event WrapBNB(address _stratAddress);

    /**
     * @dev Initializes the contract with a given `minDelay`.
     */
    constructor(
        uint256 _minDelay,
        uint256 _minDelayReduced,
        address[] memory proposers,
        address[] memory executors
    ) public {
        _setRoleAdmin(TIMELOCK_ADMIN_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(PROPOSER_ROLE, TIMELOCK_ADMIN_ROLE);
        _setRoleAdmin(EXECUTOR_ROLE, TIMELOCK_ADMIN_ROLE);

        _setupRole(TIMELOCK_ADMIN_ROLE, _msgSender());
        _setupRole(TIMELOCK_ADMIN_ROLE, address(this));

        // register proposers
        for (uint256 i = 0; i < proposers.length; ++i) {
            _setupRole(PROPOSER_ROLE, proposers[i]);
        }

        // register executors
        for (uint256 i = 0; i < executors.length; ++i) {
            _setupRole(EXECUTOR_ROLE, executors[i]);
        }

        minDelay = _minDelay;
        minDelayReduced = _minDelayReduced;
        emit MinDelayChange(0, minDelay);
    }

    modifier onlyRole(bytes32 role) {
        require(
            hasRole(role, _msgSender()),
            "TimelockController: sender requires permission"
        );
        _;
    }

    /**
     * @dev Contract might receive/hold ETH as part of the maintenance process.
     */
    receive() external payable {}

    /**
     * @dev Returns whether an id correspond to a registered operation. This
     * includes both Pending, Ready and Done operations.
     */
    function isOperation(bytes32 id) public view virtual returns (bool pending) {
        return _timestamps[id] > 0;
    }

    /**
     * @dev Returns whether an operation is pending or not.
     */
    function isOperationPending(bytes32 id) public view returns (bool pending) {
        return _timestamps[id] > _DONE_TIMESTAMP;
    }

    /**
     * @dev Returns whether an operation is ready or not.
     */
    function isOperationReady(bytes32 id) public view returns (bool ready) {
        // solhint-disable-next-line not-rely-on-time
        return
            _timestamps[id] > _DONE_TIMESTAMP &&
            _timestamps[id] <= block.timestamp;
    }

    /**
     * @dev Returns whether an operation is done or not.
     */
    function isOperationDone(bytes32 id) public view returns (bool done) {
        return _timestamps[id] == _DONE_TIMESTAMP;
    }

    /**
     * @dev Returns the timestamp at with an operation becomes ready (0 for
     * unset operations, 1 for done operations).
     */
    function getTimestamp(bytes32 id) external view returns (uint256 timestamp) {
        return _timestamps[id];
    }

    /**
     * @dev Returns the minimum delay for an operation to become valid.
     *
     * This value can be changed by executing an operation that calls `updateDelay`.
     */
    function getMinDelay() external view returns (uint256 duration) {
        return minDelay;
    }

    /**
     * @dev Returns the identifier of an operation containing a single
     * transaction.
     */
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32 hash) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    /**
     * @dev Returns the identifier of an operation containing a batch of
     * transactions.
     */
    function hashOperationBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt
    ) public pure returns (bytes32 hash) {
        return keccak256(abi.encode(targets, values, datas, predecessor, salt));
    }

    /**
     * @dev Schedule an operation containing a single transaction.
     *
     * Emits a {CallScheduled} event.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external virtual onlyRole(PROPOSER_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _schedule(id, delay);
        emit CallScheduled(id, 0, target, value, data, predecessor, delay);
    }

    /**
     * @dev Schedule an operation containing a batch of transactions.
     *
     * Emits one {CallScheduled} event per transaction in the batch.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external virtual onlyRole(PROPOSER_ROLE) {
        require(
            targets.length == values.length,
            "TimelockController: length mismatch"
        );
        require(
            targets.length == datas.length,
            "TimelockController: length mismatch"
        );

        bytes32 id =
            hashOperationBatch(targets, values, datas, predecessor, salt);
        _schedule(id, delay);
        for (uint256 i = 0; i < targets.length; ++i) {
            emit CallScheduled(
                id,
                i,
                targets[i],
                values[i],
                datas[i],
                predecessor,
                delay
            );
        }
    }

    /**
     * @dev Schedule an operation that is to becomes valid after a given delay.
     */
    function _schedule(bytes32 id, uint256 delay) private {
        require(
            _timestamps[id] == 0,
            "TimelockController: operation already scheduled"
        );
        require(delay >= minDelay, "TimelockController: insufficient delay");
        // solhint-disable-next-line not-rely-on-time
        _timestamps[id] = SafeMath.add(block.timestamp, delay);
    }

    /**
     * @dev Cancel an operation.
     *
     * Requirements:
     *
     * - the caller must have the 'proposer' role.
     */
    function cancel(bytes32 id) external virtual onlyRole(PROPOSER_ROLE) {
        require(
            isOperationPending(id),
            "TimelockController: operation cannot be cancelled"
        );
        delete _timestamps[id];

        emit Cancelled(id);
    }

    /**
     * @dev Execute an (ready) operation containing a single transaction.
     *
     * Emits a {CallExecuted} event.
     *
     * Requirements:
     *
     * - the caller must have the 'executor' role.
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external payable virtual nonReentrant onlyRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        _beforeCall(id, predecessor);
        _call(id, 0, target, value, data);
        _afterCall(id);
    }

    /**
     * @dev Execute an (ready) operation containing a batch of transactions.
     *
     * Emits one {CallExecuted} event per transaction in the batch.
     *
     * Requirements:
     *
     * - the caller must have the 'executor' role.
     */
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        bytes32 predecessor,
        bytes32 salt
    ) external payable virtual onlyRole(EXECUTOR_ROLE) {
        require(
            targets.length == values.length,
            "TimelockController: length mismatch"
        );
        require(
            targets.length == datas.length,
            "TimelockController: length mismatch"
        );

        bytes32 id =
            hashOperationBatch(targets, values, datas, predecessor, salt);
        _beforeCall(id, predecessor);
        for (uint256 i = 0; i < targets.length; ++i) {
            _call(id, i, targets[i], values[i], datas[i]);
        }
        _afterCall(id);
    }

    /**
     * @dev Checks before execution of an operation's calls.
     */
    function _beforeCall(bytes32 id, bytes32 predecessor) private view {
        require(
            isOperationReady(id),
            "TimelockController: operation is not ready"
        );
        require(
            predecessor == bytes32(0) || isOperationDone(predecessor),
            "TimelockController: missing dependency"
        );
    }

    /**
     * @dev Checks after execution of an operation's calls.
     */
    function _afterCall(bytes32 id) private {
        require(
            isOperationReady(id),
            "TimelockController: operation is not ready"
        );
        _timestamps[id] = _DONE_TIMESTAMP;
    }

    /**
     * @dev Execute an operation's call.
     *
     * Emits a {CallExecuted} event.
     */
    function _call(
        bytes32 id,
        uint256 index,
        address target,
        uint256 value,
        bytes calldata data
    ) private {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = target.call{value: value}(data);
        require(success, "TimelockController: underlying transaction reverted");

        emit CallExecuted(id, index, target, value, data);
    }

    /**
     * @dev Changes the minimum timelock duration for future operations.
     *
     * Emits a {MinDelayChange} event.
     *
     * Requirements:
     *
     * - the caller must be the timelock itself. This can only be achieved by scheduling and later executing
     * an operation where the timelock is the target and the data is the ABI-encoded call to this function.
     */
    function updateMinDelay(uint256 newDelay) external virtual {
        require(
            msg.sender == address(this),
            "TimelockController: caller must be timelock"
        );
        emit MinDelayChange(minDelay, newDelay);
        minDelay = newDelay;
    }

    function updateMinDelayReduced(uint256 newDelayReduced) external virtual {
        require(
            msg.sender == address(this),
            "TimelockController: caller must be timelock"
        );
        emit MinDelayReducedChange(minDelayReduced, newDelayReduced);
        minDelayReduced = newDelayReduced;
    }

    /**
     * @dev Reduced timelock functions
     */
    function scheduleSet(
        address _autofarmAddress,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bool _locked,
        bytes32 predecessor,
        bytes32 salt
    ) external onlyRole(EXECUTOR_ROLE) {
        bytes32 id =
            keccak256(
                abi.encode(
                    _autofarmAddress,
                    _pid,
                    _allocPoint,
                    _withUpdate,
                    _locked,
                    predecessor,
                    salt
                )
            );

        require(
            _timestamps[id] == 0,
            "TimelockController: operation already scheduled"
        );

        _timestamps[id] = SafeMath.add(block.timestamp, minDelayReduced);
        emit SetScheduled(
            id,
            0,
            _pid,
            _allocPoint,
            _withUpdate,
            _locked,
            predecessor,
            minDelayReduced
        );
    }

    function executeSet(
        address _autofarmAddress,
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bool _locked,
        bytes32 predecessor,
        bytes32 salt
    ) external payable virtual nonReentrant onlyRole(EXECUTOR_ROLE) {
        bytes32 id =
            keccak256(
                abi.encode(
                    _autofarmAddress,
                    _pid,
                    _allocPoint,
                    _withUpdate,
                    _locked,
                    predecessor,
                    salt
                )
            );

        _beforeCall(id, predecessor);
        IUpFarm(_autofarmAddress).set(_pid, _allocPoint, _withUpdate, _locked);
        _afterCall(id);

        emit SetExecuted(
            id,
            0,
            _pid,
            _allocPoint,
            _withUpdate,
            predecessor
        );
    }

    function add(
        address _autofarmAddress,
        address _want,
        bool _withUpdate,
        address _strat,
        bool _locked
    ) external onlyRole(EXECUTOR_ROLE) {
        IUpFarm(_autofarmAddress).add(0, IERC20(_want), _withUpdate, _strat, _locked); // allocPoint = 0. Schedule set (timelocked) to increase allocPoint
        emit Add(_autofarmAddress, _want, _withUpdate, _strat, _locked);
    }

    function earn(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).earn();
        emit Earn(_stratAddress);
    }

    function farm(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).farm();
        emit Farm(_stratAddress);
    }

    function pause(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).pause();
        emit Pause(_stratAddress);
    }

    function unpause(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).unpause();
        emit UnPause(_stratAddress);
    }

    function wrapBNB(address _stratAddress) external onlyRole(EXECUTOR_ROLE) {
        IStrategy(_stratAddress).wrapBNB();
        emit WrapBNB(_stratAddress);
    }
}