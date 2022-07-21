// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IPancakeswapFarm.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IWBNB.sol";
import "./refs/CoreRef.sol";

interface IBurnable {
    function burn(uint256 amount) external;
}

abstract contract Strategy is Ownable, CoreRef, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant MINIMUM_SHARES = 10 ** 4;

    bool public isCAKEStaking;
    bool public isSameAssetDeposit;
    bool public isAutoComp;
    bool public isCollect;

    bool public onlyGov = true;

    address public farmContractAddress;
    uint256 public pid;
    address public wantAddress;
    address public token0Address;
    address public token1Address;
    address public earnedAddress;

    address public wbnbAddress;
    address public UPFarmAddress;
    address public UPAddress;

    uint256 public lastEarnBlock = 0;
    uint256 public wantLockedTotal = 0;
    uint256 public sharesTotal = 0;

    uint256 public controllerFee = 0; // 70;
    uint256 public constant controllerFeeMax = 10000; // 100 = 1%
    uint256 public constant controllerFeeUL = 9900;

    uint256 public buyBackRate = 0; // 250;
    uint256 public constant buyBackRateMax = 10000; // 100 = 1%
    uint256 public constant buyBackRateUL = 9900;
    address public rewardsAddress;

    uint256 public entranceFeeFactor = 9990; // < 0.1% entrance fee - goes to pool + prevents front-running
    uint256 public constant entranceFeeFactorMax = 10000;
    uint256 public constant entranceFeeFactorLL = 9000; // 10% is the max entrance fee settable. LL = lowerlimit

    uint256 public withdrawFeeFactor = 10000; // 0.1% withdraw fee - goes to pool
    uint256 public constant withdrawFeeFactorMax = 10000;
    uint256 public constant withdrawFeeFactorLL = 9000; // 10% is the max entrance fee settable. LL = lowerlimit

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 999;

    address public earnedToToken0Router0Address;
    address public earnedToToken0Router1Address;
    address public earnedToToken1Router0Address;
    address public earnedToToken1Router1Address;
    address public wantRouterAddress;
    address public buyBackRouter0Address;
    address public buyBackRouter1Address;
    address[] public earnedToUpPath0;
    address[] public earnedToUpPath1;
    address[] public earnedToToken0Path0;
    address[] public earnedToToken0Path1;
    address[] public earnedToToken1Path0;
    address[] public earnedToToken1Path1;

    event SetSettings(
        uint256 _entranceFeeFactor,
        uint256 _withdrawFeeFactor,
        uint256 _controllerFee,
        uint256 _buyBackRate,
        uint256 _slippageFactor
    );

    event SetRewardsAddress(address _rewardsAddress);
    event SetCollect(bool _isCollect);
    event SetEarnedToUpPath(address[] _earnedToUpPath0, address[] _earnedToUpPath1);
    event SetEarnedToToken0Path(address[] _earnedToToken0Path0, address[] _earnedToToken0Path1);
    event SetEarnedToToken1Path(address[] _earnedToToken1Path0, address[] _earnedToToken1Path1);
    event SetEarnedToToken0RouterAddress(address _earnedToToken0Router0Address, address _earnedToToken0Router1Address);
    event SetEarnedToToken1RouterAddress(address _earnedToToken1Router0Address, address _earnedToToken1Router1Address);
    event SetWantRouterAddress(address _wantRouterAddress);
    event SetBuyBackRouterAddress(address _buyBackRouter0Address, address _buyBackRouter1Address);
    event SetOnlyGov(bool _onlyGov);
    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);

    function deposit(uint256 _wantAmt)
        external
        virtual
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256)
    {
        bool isFirst = sharesTotal == 0;
        require(!isFirst || _wantAmt > MINIMUM_SHARES, "first deposit amount <= MINIMUM_SHARES");

        uint256 beforeAmount =  IERC20(wantAddress).balanceOf(address(this));
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );
        uint256 afterAmount =  IERC20(wantAddress).balanceOf(address(this));

        uint256 realamount = afterAmount.sub(beforeAmount);

        uint256 sharesAdded = realamount;
        if (wantLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = realamount
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        if (isAutoComp) {
            _farm(realamount);
        } else {
            wantLockedTotal = wantLockedTotal.add(realamount);
        }

        if (isFirst) {
            sharesAdded = sharesAdded.sub(MINIMUM_SHARES);
        }

        if (isAutoComp && isCollect) {
            _collect();
        }

        emit Deposit(msg.sender, realamount);
        return sharesAdded;
    }

    function farm() external virtual onlyGuardianOrGovernor nonReentrant {
        _farm(IERC20(wantAddress).balanceOf(address(this)));
    }

    function _farm(uint256 wantAmt) internal virtual {
        require(isAutoComp, "!isAutoComp");
        wantLockedTotal = wantLockedTotal.add(wantAmt);
        IERC20(wantAddress).safeIncreaseAllowance(farmContractAddress, wantAmt);

        if (isCAKEStaking) {
            IPancakeswapFarm(farmContractAddress).enterStaking(wantAmt);
        } else {
            IPancakeswapFarm(farmContractAddress).deposit(pid, wantAmt);
        }
    }

    function _unfarm(uint256 _wantAmt) internal virtual {
        if (isCAKEStaking) {
            IPancakeswapFarm(farmContractAddress).leaveStaking(_wantAmt);
        } else {
            IPancakeswapFarm(farmContractAddress).withdraw(pid, _wantAmt);
        }
    }

    function _collect() internal virtual {
        if (earnedAddress == wbnbAddress) {
            _wrapBNB();
        }
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        if (earnedAmt > 0 && rewardsAddress != address(0)) {
            IERC20(earnedAddress).safeTransfer(rewardsAddress, earnedAmt);
        }
    }

    function withdraw(uint256 _wantAmt)
        public
        virtual
        onlyOwner
        nonReentrant
        returns (uint256)
    {        
        require(_wantAmt > 0, "_wantAmt <= 0");
        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        require(sharesRemoved > 0, "sharesRemoved <= 0");
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);

        if (withdrawFeeFactor < withdrawFeeFactorMax) {
            _wantAmt = _wantAmt.mul(withdrawFeeFactor).div(
                withdrawFeeFactorMax
            );
        }

        if (isAutoComp) {
            _unfarm(_wantAmt);
        }

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        IERC20(wantAddress).safeTransfer(UPFarmAddress, _wantAmt);

        if (isAutoComp && isCollect) {
            _collect();
        }

        emit Withdraw(msg.sender,_wantAmt);

        return sharesRemoved;
    }

    function harvest() internal virtual {
        _unfarm(0);
    }

    function earn() external virtual nonReentrant whenNotPaused {
        require(isAutoComp, "!isAutoComp");
        require(
            !onlyGov || core().isGovernor(msg.sender) || core().isGuardian(msg.sender),
            "!gov"
        );

        harvest();

        if (isCollect) {
            _collect();
            lastEarnBlock = block.number;
            return;
        }

        if (earnedAddress == wbnbAddress) {
            _wrapBNB();
        }

        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        earnedAmt = distributeFees(earnedAmt);
        earnedAmt = buyBack(earnedAmt);

        if (isCAKEStaking || isSameAssetDeposit) {
            lastEarnBlock = block.number;
            _farm(IERC20(wantAddress).balanceOf(address(this)));
            return;
        }

        if (token0Address == token1Address) {
            IERC20(earnedAddress).safeApprove(earnedToToken0Router0Address, 0);
            IERC20(earnedAddress).safeIncreaseAllowance(
                earnedToToken0Router0Address,
                earnedAmt
            );
            _safeSwapAuto(
                earnedToToken0Router0Address,
                earnedToToken0Router1Address,
                earnedAmt,
                slippageFactor,
                earnedToToken0Path0,
                earnedToToken0Path1,
                address(this),
                block.timestamp.add(600)
            );
        } else {
            if (earnedAddress != token0Address) {
                IERC20(earnedAddress).safeApprove(earnedToToken0Router0Address, 0);
                IERC20(earnedAddress).safeIncreaseAllowance(
                    earnedToToken0Router0Address,
                    earnedAmt.div(2)
                );
                _safeSwapAuto(
                    earnedToToken0Router0Address,
                    earnedToToken0Router1Address,
                    earnedAmt.div(2),
                    slippageFactor,
                    earnedToToken0Path0,
                    earnedToToken0Path1,
                    address(this),
                    block.timestamp.add(600)
                );
            }

            if (earnedAddress != token1Address) {
                IERC20(earnedAddress).safeApprove(earnedToToken1Router0Address, 0);
                IERC20(earnedAddress).safeIncreaseAllowance(
                    earnedToToken1Router0Address,
                    earnedAmt.div(2)
                );
                _safeSwapAuto(
                    earnedToToken1Router0Address,
                    earnedToToken1Router1Address,
                    earnedAmt.div(2),
                    slippageFactor,
                    earnedToToken1Path0,
                    earnedToToken1Path1,
                    address(this),
                    block.timestamp.add(600)
                );
            }

            uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
            uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
            if (token0Amt > 0 && token1Amt > 0) {
                IERC20(token0Address).safeIncreaseAllowance(
                    wantRouterAddress,
                    token0Amt
                );
                IERC20(token1Address).safeIncreaseAllowance(
                    wantRouterAddress,
                    token1Amt
                );
                IPancakeRouter02(wantRouterAddress).addLiquidity(
                    token0Address,
                    token1Address,
                    token0Amt,
                    token1Amt,
                    0,
                    0,
                    address(this),
                    block.timestamp.add(600)
                );
            }
        }

        lastEarnBlock = block.number;

        _farm(IERC20(wantAddress).balanceOf(address(this)));
    }

    function buyBack(uint256 _earnedAmt) internal virtual returns (uint256) {
        if (buyBackRate <= 0) {
            return _earnedAmt;
        }

        uint256 buyBackAmt = _earnedAmt.mul(buyBackRate).div(buyBackRateMax);
        uint256 burnAmt = buyBackAmt;
        if (earnedAddress != UPAddress) {
            IERC20(earnedAddress).safeApprove(buyBackRouter0Address, 0);
            IERC20(earnedAddress).safeIncreaseAllowance(
                buyBackRouter0Address,
                buyBackAmt
            );
            uint256 before = IERC20(UPAddress).balanceOf(address(this));
            _safeSwapAuto(
                buyBackRouter0Address,
                buyBackRouter1Address,
                buyBackAmt,
                slippageFactor,
                earnedToUpPath0,
                earnedToUpPath1,
                address(this),
                block.timestamp.add(600)
            );
            burnAmt = IERC20(UPAddress).balanceOf(address(this)).sub(before);
        }

        IBurnable(UPAddress).burn(burnAmt);

        return _earnedAmt.sub(buyBackAmt);
    }

    function distributeFees(uint256 _earnedAmt)
        internal
        virtual
        returns (uint256)
    {
        if (_earnedAmt > 0) {
            if (controllerFee > 0) {
                uint256 fee =
                    _earnedAmt.mul(controllerFee).div(controllerFeeMax);
                IERC20(earnedAddress).safeTransfer(rewardsAddress, fee);
                _earnedAmt = _earnedAmt.sub(fee);
            }
        }

        return _earnedAmt;
    }

    function setSettings(
        uint256 _entranceFeeFactor,
        uint256 _withdrawFeeFactor,
        uint256 _controllerFee,
        uint256 _buyBackRate,
        uint256 _slippageFactor
    ) external virtual onlyGovernor {
        require(
            _entranceFeeFactor >= entranceFeeFactorLL,
            "_entranceFeeFactor too low"
        );
        require(
            _entranceFeeFactor <= entranceFeeFactorMax,
            "_entranceFeeFactor too high"
        );
        entranceFeeFactor = _entranceFeeFactor;

        require(
            _withdrawFeeFactor >= withdrawFeeFactorLL,
            "_withdrawFeeFactor too low"
        );
        require(
            _withdrawFeeFactor <= withdrawFeeFactorMax,
            "_withdrawFeeFactor too high"
        );
        withdrawFeeFactor = _withdrawFeeFactor;

        require(_controllerFee <= controllerFeeUL, "_controllerFee too high");
        controllerFee = _controllerFee;

        require(_buyBackRate <= buyBackRateUL, "_buyBackRate too high");
        buyBackRate = _buyBackRate;

        require(
            _slippageFactor <= slippageFactorUL,
            "_slippageFactor too high"
        );
        slippageFactor = _slippageFactor;

        emit SetSettings(
            _entranceFeeFactor,
            _withdrawFeeFactor,
            _controllerFee,
            _buyBackRate,
            _slippageFactor
        );
    }

    function setRewardsAddress(address _rewardsAddress)
        external
        virtual
        onlyGovernor
    {
        rewardsAddress = _rewardsAddress;
        emit SetRewardsAddress(_rewardsAddress);
    }

    function setCollect(bool _isCollect)
        external
        virtual
        onlyGovernor
    {
        isCollect = _isCollect;
        emit SetCollect(_isCollect);
    }

    function setEarnedToUpPath(address[] memory _earnedToUpPath0, address[] memory _earnedToUpPath1)
        external
        onlyGovernor
    {
        require(
            _checkPath(_earnedToUpPath0, _earnedToUpPath1, earnedAddress, UPAddress),
            "invalid _earnedToUpPath"
        );
        earnedToUpPath0 = _earnedToUpPath0;
        earnedToUpPath1 = _earnedToUpPath1;
        emit SetEarnedToUpPath(_earnedToUpPath0, _earnedToUpPath1);
    }

    function setEarnedToToken0Path(address[] memory _earnedToToken0Path0, address[] memory _earnedToToken0Path1)
        external
        onlyGovernor
    {
        require(
            _checkPath(_earnedToToken0Path0, _earnedToToken0Path1, earnedAddress, token0Address),
            "invalid _earnedToToken0Path"
        );
        earnedToToken0Path0 = _earnedToToken0Path0;
        earnedToToken0Path1 = _earnedToToken0Path1;
        emit SetEarnedToToken0Path(_earnedToToken0Path0, _earnedToToken0Path1);
    }

    function setEarnedToToken1Path(address[] memory _earnedToToken1Path0, address[] memory _earnedToToken1Path1)
        external
        onlyGovernor
    {
        require(
            token0Address == token1Address || _checkPath(_earnedToToken1Path0, _earnedToToken1Path1, earnedAddress, token1Address),
            "invalid _earnedToToken1Path"
        );
        earnedToToken1Path0 = _earnedToToken1Path0;
        earnedToToken1Path1 = _earnedToToken1Path1;
        emit SetEarnedToToken1Path(_earnedToToken1Path0, _earnedToToken1Path1);
    }

    function setEarnedToToken0RouterAddress(address _earnedToToken0Router0Address, address _earnedToToken0Router1Address)
        external
        virtual
        onlyGovernor
    {
        earnedToToken0Router0Address = _earnedToToken0Router0Address;
        earnedToToken0Router1Address = _earnedToToken0Router1Address;
        emit SetEarnedToToken0RouterAddress(_earnedToToken0Router0Address, _earnedToToken0Router1Address);
    }

    function setEarnedToToken1RouterAddress(address _earnedToToken1Router0Address, address _earnedToToken1Router1Address)
        external
        virtual
        onlyGovernor
    {
        earnedToToken1Router0Address = _earnedToToken1Router0Address;
        earnedToToken1Router1Address = _earnedToToken1Router1Address;
        emit SetEarnedToToken1RouterAddress(_earnedToToken1Router0Address, _earnedToToken1Router1Address);
    }

    function setWantRouterAddress(address _wantRouterAddress)
        external
        virtual
        onlyGovernor
    {
        wantRouterAddress = _wantRouterAddress;
        emit SetWantRouterAddress(_wantRouterAddress);
    }

    function setBuyBackRouterAddress(address _buyBackRouter0Address, address _buyBackRouter1Address)
        external
        virtual
        onlyGovernor
    {
        buyBackRouter0Address = _buyBackRouter0Address;
        buyBackRouter1Address = _buyBackRouter1Address;
        emit SetBuyBackRouterAddress(_buyBackRouter0Address, _buyBackRouter1Address);
    }

    function setOnlyGov(bool _onlyGov) external virtual onlyGovernor {
        onlyGov = _onlyGov;
        emit SetOnlyGov(_onlyGov);
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount,
        address _to
    ) external virtual onlyGovernor {
        require(_token != earnedAddress, "!safe");
        require(_token != wantAddress, "!safe");
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function _wrapBNB() internal virtual {
        // BNB -> WBNB
        uint256 bnbBal = address(this).balance;
        if (bnbBal > 0) {
            IWBNB(wbnbAddress).deposit{value: bnbBal}(); // BNB -> WBNB
        }
    }

    function wrapBNB() external virtual onlyGovernor {
        _wrapBNB();
    }

    function _safeSwap(
        address _routerAddress,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path,
        address _to,
        uint256 _deadline
    ) internal virtual {
        uint256[] memory amounts =
            IPancakeRouter02(_routerAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IPancakeRouter02(_routerAddress)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amountIn,
            amountOut.mul(_slippageFactor).div(1000),
            _path,
            _to,
            _deadline
        );
    }

    function _safeSwapCrossRouter(
        address _router0Address,
        address _router1Address,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path0,
        address[] memory _path1,
        address _to,
        uint256 _deadline
    ) internal virtual {
        IERC20 midToken = IERC20(_path0[_path0.length - 1]);
        uint256 before = midToken.balanceOf(address(this));
        _safeSwap(
            _router0Address,
            _amountIn,
            _slippageFactor,
            _path0,
            address(this),
            _deadline
        );
        uint256 _amountMid = midToken.balanceOf(address(this)).sub(before);
        if (_amountMid > 0) {
            midToken.safeApprove(_router1Address, 0);
            midToken.safeIncreaseAllowance(
                _router1Address,
                _amountMid
            );
            _safeSwap(
                _router1Address,
                _amountMid,
                _slippageFactor,
                _path1,
                _to,
                _deadline
            );
        }
    }

    function _safeSwapAuto(
        address _router0Address,
        address _router1Address,
        uint256 _amountIn,
        uint256 _slippageFactor,
        address[] memory _path0,
        address[] memory _path1,
        address _to,
        uint256 _deadline
    ) internal virtual {
        if (_router1Address == address(0)) {
            _safeSwap(
                _router0Address,
                _amountIn,
                _slippageFactor,
                _path0,
                _to,
                _deadline
            );
        } else {
            _safeSwapCrossRouter(
                _router0Address,
                _router1Address,
                _amountIn,
                _slippageFactor,
                _path0,
                _path1,
                _to,
                _deadline
            );
        }
    }

    function _checkPath(address[] memory path0, address[] memory path1, address from, address to) internal virtual view returns (bool) {
        uint len0 = path0.length;
        uint len1 = path1.length;
        if (isCollect || from == to) {
            return len0 == 0 && len1 == 0;
        }
        return len0 >= 2 &&
            path0[0] == from &&
            (
                (len1 == 0 && path0[len0 - 1] == to) ||
                (len1 >= 2 && path0[len0 - 1] == path1[0] && path1[len1 - 1] == to)
            );
    }
}
