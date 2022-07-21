// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IVestingMaster.sol";
import "./refs/CoreRef.sol";

interface IStrategy {

    function deposit( uint256 _wantAmt)
        external
        returns (uint256);

    function withdraw( uint256 _wantAmt)
        external
        returns (uint256);

    function wantAddress() external view returns (address);
    function wantLockedTotal() external view returns (uint256);
    function sharesTotal() external view returns (uint256);
}

interface IUPToken {
    function mint(address _to, uint256 _amount) external;
}

contract UpFarm is CoreRef, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 shares;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 want;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accTokenPerShare;
        address strat;
        bool locked;
    }

    address public rewardToken;
    address public vestingMaster;
    uint256 public tokenPerBlock;
    uint256 public startBlock;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;

    mapping(address => bool) public poolExistence;

    uint256 private _accShareReward;

    uint256 private _accHarvestedReward;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, uint256 shares, uint256 rewardDebt);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, uint256 shares, uint256 rewardDebt);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event UpdatePool(
        address want,
        uint256 accTokenPerShare,
        uint256 reward,
        uint256 sharesTotal
    );
    event UpdateTokenPerBlock(address indexed user,uint256 amount);
    event SetVestingMaster(address indexed user,address vesting);
    event Add( 
        uint256 _allocPoint,
        address _want,
        address _strat,
        bool _locked
    );

    event Set( 
        uint256 _pid,
        uint256 _allocPoint,
        bool _locked
    );

    modifier nonDuplicated(address _strat) {
        require(
            !poolExistence[_strat],
            "UpFarm::nonDuplicated: Duplicated"
        );
        _;
    }

    constructor(
        address _core,
        address _rewardToken,
        address _vestingMaster,
        uint256 _tokenPerBlock,
        uint256 _startBlock
    ) public CoreRef(_core) {
        rewardToken = _rewardToken;
        vestingMaster = _vestingMaster;
        tokenPerBlock = _tokenPerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat,
        bool _locked
    ) external onlyGuardianOrGovernor nonDuplicated(_strat) {
        require(address(_want) == IStrategy(_strat).wantAddress(), "UpFarm::add: Invalid want");

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accTokenPerShare: 0,
                strat: _strat,
                locked: _locked
            })
        );
        poolExistence[_strat] = true;
        emit Add(_allocPoint, address(_want), _strat, _locked);
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate,
        bool _locked
    ) external onlyGuardianOrGovernor {
        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].locked = _locked;

        emit Set(_pid, _allocPoint, _locked);
    }

    function getMultiplier(uint256 _from, uint256 _to) internal pure returns (uint256) {
        return _to.sub(_from);
    }

    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = 0;
            if (totalAllocPoint > 0) {
                tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            }
            accTokenPerShare = accTokenPerShare.add(
                tokenReward.mul(1e12).div(sharesTotal)
            );
        }
        return user.shares.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal = IStrategy(pool.strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (sharesTotal < wantLockedTotal && amount.mul(sharesTotal) < user.shares.mul(wantLockedTotal)) {
            amount = amount.add(1);
        }
        return amount;
    }

    function massUpdatePools() public {
        for (uint256 pid = 0; pid < poolInfo.length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (multiplier == 0) {
            return;
        }
        uint256 reward = 0;
        if (totalAllocPoint > 0) {
            reward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        }
        pool.accTokenPerShare = pool.accTokenPerShare.add(
            reward.mul(1e12).div(sharesTotal)
        );
        pool.lastRewardBlock = block.number;
        _accShareReward = _accShareReward.add(reward);
        emit UpdatePool(
            address(pool.want),
            pool.accTokenPerShare,
            reward,
            sharesTotal
        );
    }

    function deposit(uint256 _pid, uint256 _wantAmt) external nonReentrant {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            uint256 pending =
                user.shares.mul(pool.accTokenPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                uint256 locked;
                if (pool.locked && vestingMaster != address(0)) {
                    locked = pending
                        .div(IVestingMaster(vestingMaster).lockedPeriodAmount().add(1))
                        .mul(IVestingMaster(vestingMaster).lockedPeriodAmount());
                }
                safeTokenTransfer(msg.sender, pending.sub(locked));
                if (locked > 0) {
                    uint256 actualAmount = safeTokenTransfer(
                        vestingMaster,
                        locked
                    );
                    IVestingMaster(vestingMaster).lock(msg.sender, actualAmount);
                }
                _accHarvestedReward = _accHarvestedReward.add(pending);
            }
        }
        uint256 realAmount = _wantAmt;
        if (_wantAmt > 0) {
            uint256 beforeAmount = pool.want.balanceOf(address(this));
            pool.want.safeTransferFrom(
                address(msg.sender),
                address(this),
                _wantAmt
            );
            uint256 afterAmount = pool.want.balanceOf(address(this));
            realAmount = afterAmount.sub(beforeAmount);
            pool.want.safeIncreaseAllowance(pool.strat, realAmount);
            uint256 sharesAdded =
                IStrategy(pool.strat).deposit(realAmount);
            user.shares = user.shares.add(sharesAdded);
        }
        user.rewardDebt = user.shares.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, realAmount, user.shares, user.rewardDebt);
    }

    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant {
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(pool.strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        uint256 pending =
            user.shares.mul(pool.accTokenPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            uint256 locked;
            if (pool.locked && vestingMaster != address(0)) {
                locked = pending
                    .div(IVestingMaster(vestingMaster).lockedPeriodAmount().add(1))
                    .mul(IVestingMaster(vestingMaster).lockedPeriodAmount());
            }
            safeTokenTransfer(msg.sender, pending.sub(locked));
            if (locked > 0) {
                uint256 actualAmount = safeTokenTransfer(
                    vestingMaster,
                    locked
                );
                IVestingMaster(vestingMaster).lock(msg.sender, actualAmount);
            }
            _accHarvestedReward = _accHarvestedReward.add(pending);
        }

        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (sharesTotal < wantLockedTotal && amount.mul(sharesTotal) < user.shares.mul(wantLockedTotal)) {
            amount = amount.add(1);
        }
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved =
                IStrategy(poolInfo[_pid].strat).withdraw(_wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(address(msg.sender), _wantAmt);
        }
        user.rewardDebt = user.shares.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _wantAmt, user.shares, user.rewardDebt);
    }

    function withdrawAll(uint256 _pid) external {
        withdraw(_pid, uint256(-1));
    }

    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal =
            IStrategy(pool.strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (sharesTotal < wantLockedTotal && amount.mul(sharesTotal) < user.shares.mul(wantLockedTotal)) {
            amount = amount.add(1);
        }

        user.shares = 0;
        user.rewardDebt = 0;

        IStrategy(pool.strat).withdraw(amount);
        uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
        if (wantBal < amount) {
            amount = wantBal;
        }
        pool.want.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);        
    }

    function safeTokenTransfer(address _to, uint256 _amount) internal returns (uint256) {
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > balance) {
            _amount = balance;
        }
        IERC20(rewardToken).safeTransfer(_to, _amount);
        return _amount;
    }

    function setVestingMaster(address _master) external onlyGovernor {
        vestingMaster = _master;
        emit SetVestingMaster(msg.sender, _master);
    }

    function updateTokenPerBlock(uint256 _tokenPerBlock) external onlyGuardianOrGovernor {
        massUpdatePools();
        tokenPerBlock = _tokenPerBlock;
        emit UpdateTokenPerBlock(msg.sender, _tokenPerBlock);
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) external onlyGovernor {
        require(_token != rewardToken, "!safe");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    function getNoHarvestReward() public view returns (uint256) {
        return _accShareReward.sub(_accHarvestedReward);
    }
}
