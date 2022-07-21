// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IStakingRewards.sol";
import "./interfaces/IVestingMaster.sol";
import "./refs/CoreRef.sol";

contract StakingRewards is
    IStakingRewards,
    ReentrancyGuard,
    ERC20,
    CoreRef
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IVestingMaster public override vestingMaster;

    // Info of each pool.
    PoolInfo[] public override poolInfo;

    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public override userInfo;

    // Pair corresponding pid
    mapping(address => uint256) public override pair2Pid;
    mapping(IERC20 => bool) public override poolExistence;

    // reward tokens created per block.
    uint256 public override tokenPerBlock;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public override totalAllocPoint = 0;

    // The block number when reward mining starts.
    uint256 public override startBlock;

    // The block number when reward mining ends.
    uint256 public override endBlock;

    IERC20 public override rewardToken;

    IERC20 public override upToken;

    uint256 private _accShareReward;

    uint256 private _accHarvestedReward;

    event AddPool( 
        uint256 _allocPoint,
        address _lpToken,
        bool _locked
    );

    event SetPool( 
        uint256 _pid,
        uint256 _allocPoint,
        bool _locked
    );

    constructor(
        address _core,
        address _upToken,
        address _rewardToken,
        address _vestingMaster,
        uint256 _tokenPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public ERC20("UP Farms Seed Token", "UPSEED") CoreRef(_core) {
        require(
            _startBlock < _endBlock,
            "StakingReward::constructor: End less than start"
        );
        upToken = IERC20(_upToken);
        rewardToken = IERC20(_rewardToken);
        vestingMaster = IVestingMaster(_vestingMaster);
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
    }

    modifier nonDuplicated(IERC20 _lpToken) {
        require(
            !poolExistence[_lpToken],
            "StakingReward::nonDuplicated: Duplicated"
        );
        require(
            _lpToken != rewardToken || _lpToken == upToken,
            "StakingReward::nonDuplicated: Duplicated reward and lp"
        );
        _;
    }

    modifier validatePid(uint256 _pid) {
        require(
            _pid < poolInfo.length,
            "StakingReward::validatePid: Not exist"
        );
        _;
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        revert("StakingRewards::transfer: Not support transfer");
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        revert("StakingRewards::transferFrom: Not support transferFrom");
    }

    function poolLength() public view override returns (uint256) {
        return poolInfo.length;
    }

    function addPool(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _locked
    ) external onlyGuardianOrGovernor nonDuplicated(_lpToken) {
        require(
            block.number < endBlock,
            "StakingReward::addPool: Exceed endblock"
        );
        massUpdatePools();
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

        emit AddPool(_allocPoint, address(_lpToken), _locked);
    }

    function setPool(
        uint256 _pid,
        uint256 _allocPoint,
        bool _locked
    ) external validatePid(_pid) onlyGuardianOrGovernor {
        massUpdatePools();

        totalAllocPoint = totalAllocPoint
            .sub(poolInfo[_pid].allocPoint)
            .add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].locked = _locked;

        emit SetPool(_pid, _allocPoint, _locked);
    }

    function getMultiplier(uint256 _from, uint256 _to)
        internal
        pure
        returns (uint256)
    {
        return _to.sub(_from);
    }

    function getTokenReward(uint256 _pid)
        internal
        view
        returns (uint256 tokenReward)
    {
        PoolInfo storage pool = poolInfo[_pid];
        require(
            pool.lastRewardBlock < block.number,
            "StakingReward::getTokenReward:LastRewardBlock Must little than the current block number"
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
        uint256 lpSupply = address(upToken) == address(pool.lpToken)
            ? totalSupply()
            : pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 shareReward = getTokenReward(_pid);
            accTokenPerShare = accTokenPerShare.add(
                shareReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public override validatePid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.lastRewardBlock >= endBlock) {
            return;
        }
        uint256 lpSupply = address(upToken) == address(pool.lpToken)
            ? totalSupply()
            : pool.lpToken.balanceOf(address(this));
        uint256 lastRewardBlock = block.number >= endBlock
            ? endBlock
            : block.number;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = lastRewardBlock;
            return;
        }
        uint256 shareReward = getTokenReward(_pid);
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

    function deposit(uint256 _pid, uint256 _amount)
        external
        override
        validatePid(_pid)
        nonReentrant
        whenNotPaused
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
                safeTokenTransfer(msg.sender, pending.sub(locked));
                if (locked > 0) {
                    uint256 actualAmount = safeTokenTransfer(
                        address(vestingMaster),
                        locked
                    );
                    vestingMaster.lock(msg.sender, actualAmount);
                }
                _accHarvestedReward = _accHarvestedReward.add(pending);
            }
        }
        uint256 realAmount = _amount;
        if (_amount > 0) {
            uint256 beforeAmount =  pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            uint256 afterAmount =  pool.lpToken.balanceOf(address(this));
            realAmount = afterAmount.sub(beforeAmount);
            if (address(upToken) == address(pool.lpToken)) {
                _mint(msg.sender, realAmount);
            }
            user.amount = user.amount.add(realAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, realAmount, user.amount, user.rewardDebt);
    }

    function withdraw(uint256 _pid, uint256 _amount)
        external
        override
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            user.amount >= _amount,
            "StakingReward::withdraw: Not good"
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
                safeTokenTransfer(msg.sender, pending.sub(locked));
                if (locked > 0) {
                    uint256 actualAmount = safeTokenTransfer(
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
            if (address(upToken) == address(pool.lpToken)) {
                _burn(msg.sender, _amount);
            }
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount, user.amount, user.rewardDebt);
    }

    function emergencyWithdraw(uint256 _pid)
        external
        override
        validatePid(_pid)
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        if (address(upToken) == address(pool.lpToken)) {
            _burn(msg.sender, amount);
        }
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function safeTokenTransfer(address _to, uint256 _amount)
        internal
        virtual
        returns (uint256)
    {
        uint256 balance = rewardToken.balanceOf(address(this));
        uint256 amount;
        uint256 floorAmount = rewardToken == upToken ? totalSupply() : 0;
        if (balance > floorAmount) {
            balance = balance.sub(floorAmount);
            if (_amount > balance) {
                amount = balance;
            } else {
                amount = _amount;
            }
        }

        rewardToken.safeTransfer(_to, amount);
        return amount;
    }

    function updateTokenPerBlock(uint256 _tokenPerBlock)
        external
        override
        onlyGuardianOrGovernor
    {
        massUpdatePools();
        tokenPerBlock = _tokenPerBlock;
        emit UpdateEmissionRate(msg.sender, _tokenPerBlock);
    }

    function updateEndBlock(uint256 _endBlock)
        external
        override
        onlyGuardianOrGovernor
    {
        require(
            _endBlock > startBlock && _endBlock >= block.number,
            "StakingReward::updateEndBlock: Less"
        );
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            require(
                _endBlock > poolInfo[pid].lastRewardBlock,
                "StakingReward::updateEndBlock: Less"
            );
        }
        massUpdatePools();
        endBlock = _endBlock;
        emit UpdateEndBlock(msg.sender, _endBlock);
    }

    function updateVestingMaster(address _vestingMaster)
        external
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