// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/ILiquidityMiningMaster.sol";
import "../interfaces/IVestingMaster.sol";
import "../refs/CoreRef.sol";
import "./DAOToken.sol";

// Earn Token, V1.2
contract LiquidityMiningMaster is
    ILiquidityMiningMaster,
    ReentrancyGuard,
    CoreRef,
    DAOToken
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IVestingMaster public vestingMaster;

    // Info of each pool.
    PoolInfo[] public override poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public override userInfo;

    // Pair corresponding pid
    mapping(address => uint256) public override pair2Pid;
    mapping(IERC20 => bool) public override poolExistence;

    // Reward tokens created per block.
    uint256 public override tokenPerBlock;

    // Bonus muliplier for early reward makers.
    uint256 public constant override BONUS_MULTIPLIER = 1;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public override totalAllocPoint = 0;

    // The block number when mining starts.
    uint256 public override startBlock;

    // The block number when mining ends.
    uint256 public override endBlock;

    IERC20 public override rewardToken;

    uint256 private _accShareReward;

    uint256 private _accHarvestedReward;

    address public xmsAddress;

    constructor(
        address _core,
        address _xmsAddress,
        address _vestingMaster,
        address _rewardToken,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public CoreRef(_core) DAOToken("Mars Farms Seed Token", "MSEED") {
        require(
            _startBlock < _endBlock,
            "LiquidityMiningMaster::constructor: End less than start"
        );
        xmsAddress = _xmsAddress;
        vestingMaster = IVestingMaster(_vestingMaster);
        rewardToken = IERC20(_rewardToken);
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }

    modifier nonDuplicated(IERC20 _lpToken) {
        require(
            !poolExistence[_lpToken],
            "LiquidityMiningMaster::nonDuplicated: Duplicated lp"
        );
        require(
            _lpToken != rewardToken || address(_lpToken) == xmsAddress,
            "LiquidityMiningMaster::nonDuplicated: Duplicated reward and lp"
        );
        _;
    }

    modifier validatePid(uint256 _pid) {
        require(
            _pid < poolInfo.length,
            "LiquidityMiningMaster::validatePid: Not exist"
        );
        _;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        revert("LiquidityMiningMaster::transfer: Not support transfer");
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        revert("LiquidityMiningMaster::transferFrom: Not support transferFrom");
    }

    function poolLength() public view override returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the governor.
    function addPool(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _locked,
        bool _withUpdate
    ) public override onlyGuardianOrGovernor nonDuplicated(_lpToken) {
        require(
            block.number < endBlock,
            "LiquidityMiningMaster::addPool: Exceed endblock"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accTokenPerShare: 0,
                locked: _locked
            })
        );
        pair2Pid[address(_lpToken)] = poolLength() - 1;
    }

    // Update the given pool's allocation point and deposit fee. Can only be called by the governor.
    function setPool(
        uint256 _pid,
        uint256 _allocPoint,
        bool _locked,
        bool _withUpdate
    ) public override validatePid(_pid) onlyGuardianOrGovernor {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].locked = _locked;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        pure
        override
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function _getTokenReward(uint256 _pid)
        internal
        view
        returns (uint256 tokenReward)
    {
        PoolInfo storage pool = poolInfo[_pid];
        require(
            pool.lastRewardBlock < block.number,
            "LiquidityMiningMaster::_getTokenReward: Must little than the current block number"
        );
        uint256 multiplier = getMultiplier(
            pool.lastRewardBlock,
            block.number >= endBlock ? endBlock : block.number
        );
        if (totalAllocPoint > 0) {
            tokenReward = multiplier
                .mul(tokenPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
        }
    }

    // View function to see pending reward on frontend.
    function pendingToken(uint256 _pid, address _user)
        external
        view
        override
        validatePid(_pid)
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = xmsAddress == address(pool.lpToken)
            ? totalSupply()
            : pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 shareReward = _getTokenReward(_pid);
            accTokenPerShare = accTokenPerShare.add(
                shareReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public override validatePid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.lastRewardBlock >= endBlock) {
            return;
        }
        uint256 lpSupply = xmsAddress == address(pool.lpToken)
            ? totalSupply()
            : pool.lpToken.balanceOf(address(this));
        uint256 lastRewardBlock = block.number >= endBlock
            ? endBlock
            : block.number;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = lastRewardBlock;
            return;
        }
        uint256 shareReward = _getTokenReward(_pid);
        pool.accTokenPerShare = pool.accTokenPerShare.add(
            shareReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = lastRewardBlock;
        _accShareReward = _accShareReward.add(shareReward);
        emit UpdatePool(
            address(pool.lpToken),
            pool.accTokenPerShare,
            shareReward,
            lpSupply
        );
    }

    // Deposit LP tokens to LiquidityMiningMaster for allocation.
    function deposit(uint256 _pid, uint256 _amount)
        public
        override
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accTokenPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                uint256 locked;
                if (pool.locked && address(vestingMaster) != address(0)) {
                    locked = pending
                        .div(vestingMaster.lockedPeriodAmount() + 1)
                        .mul(vestingMaster.lockedPeriodAmount());
                }
                _safeTokenTransfer(msg.sender, pending.sub(locked));
                if (locked > 0) {
                    uint256 actualAmount = _safeTokenTransfer(
                        address(vestingMaster),
                        locked
                    );
                    vestingMaster.lock(msg.sender, actualAmount);
                }
                _accHarvestedReward = _accHarvestedReward.add(pending);
            }
        }
        if (_amount > 0) {
            uint256 balance = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            _amount = pool.lpToken.balanceOf(address(this)).sub(balance);
            if (xmsAddress == address(pool.lpToken)) {
                _mint(msg.sender, _amount);
            }
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount, user.amount, user.rewardDebt);
    }

    // Withdraw LP tokens from LiquidityMiningMaster.
    function withdraw(uint256 _pid, uint256 _amount)
        public
        override
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            user.amount >= _amount,
            "LiquidityMiningMaster::withdraw: Not good"
        );
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accTokenPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                uint256 locked;
                if (pool.locked && address(vestingMaster) != address(0)) {
                    locked = pending
                        .div(vestingMaster.lockedPeriodAmount() + 1)
                        .mul(vestingMaster.lockedPeriodAmount());
                }
                _safeTokenTransfer(msg.sender, pending.sub(locked));
                if (locked > 0) {
                    uint256 actualAmount = _safeTokenTransfer(
                        address(vestingMaster),
                        locked
                    );
                    vestingMaster.lock(msg.sender, actualAmount);
                }
                _accHarvestedReward = _accHarvestedReward.add(pending);
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            if (xmsAddress == address(pool.lpToken)) {
                _burn(msg.sender, _amount);
            }
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount, user.amount, user.rewardDebt);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid)
        public
        override
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        if (xmsAddress == address(pool.lpToken)) {
            _burn(msg.sender, amount);
        }
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough token.
    function _safeTokenTransfer(address _to, uint256 _amount)
        internal
        virtual
        returns (uint256)
    {
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 amount;
        uint256 floorAmount = address(rewardToken) == xmsAddress ? totalSupply() : 0;
        if (balance > floorAmount) {
            if (_amount > balance.sub(floorAmount)) {
                amount = balance.sub(floorAmount);
            } else {
                amount = _amount;
            }
        }
        require(
            rewardToken.transfer(_to, amount),
            "LiquidityMiningMaster::safeTokenTransfer: Transfer failed"
        );
        return amount;
    }

    function updateTokenPerBlock(uint256 _tokenPerBlock)
        public
        override
        onlyGuardianOrGovernor
    {
        massUpdatePools();
        tokenPerBlock = _tokenPerBlock;
        emit UpdateEmissionRate(msg.sender, _tokenPerBlock);
    }

    function updateEndBlock(uint256 _endBlock)
        public
        override
        onlyGuardianOrGovernor
    {
        require(
            _endBlock > startBlock && _endBlock >= block.number,
            "LiquidityMiningMaster::updateEndBlock: Less"
        );
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            require(
                _endBlock > poolInfo[pid].lastRewardBlock,
                "LiquidityMiningMaster::updateEndBlock: Less"
            );
        }
        massUpdatePools();
        endBlock = _endBlock;
        emit UpdateEndBlock(msg.sender, _endBlock);
    }

    function updateVestingMaster(address _vestingMaster)
        public
        override
        onlyGovernor
    {
        vestingMaster = IVestingMaster(_vestingMaster);
        emit UpdateVestingMaster(msg.sender, _vestingMaster);
    }

    function getNoHarvestReward() public view returns (uint256) {
        return _accShareReward.sub(_accHarvestedReward);
    }
}