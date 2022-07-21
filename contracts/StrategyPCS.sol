// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./Strategy.sol";

contract StrategyPCS is Strategy {
    constructor(
        address[] memory _addresses,
        uint256 _pid,
        bool _isCAKEStaking,
        bool _isAutoComp,
        bool _isCollect,
        address[] memory _earnedToUpPath0,
        address[] memory _earnedToUpPath1,
        address[] memory _earnedToToken0Path0,
        address[] memory _earnedToToken0Path1,
        address[] memory _earnedToToken1Path0,
        address[] memory _earnedToToken1Path1,
        uint256 _controllerFee,
        uint256 _buyBackRate,
        uint256 _entranceFeeFactor,
        uint256 _withdrawFeeFactor
    ) public CoreRef(_addresses[0]) {
        wbnbAddress = _addresses[1];
        UPFarmAddress = _addresses[2];
        UPAddress = _addresses[3];
        wantAddress = _addresses[4];
        token0Address = _addresses[5];
        token1Address = _addresses[6];
        earnedAddress = _addresses[7];
        farmContractAddress = _addresses[8];
        rewardsAddress = _addresses[9];
        wantRouterAddress = _addresses[10];
        earnedToToken0Router0Address = _addresses[11];
        earnedToToken0Router1Address = _addresses[12];
        earnedToToken1Router0Address = _addresses[13];
        earnedToToken1Router1Address = _addresses[14];
        buyBackRouter0Address = _addresses[15];
        buyBackRouter1Address = _addresses[16];

        pid = _pid;
        isCAKEStaking = _isCAKEStaking;
        isSameAssetDeposit = wantAddress == earnedAddress;
        isAutoComp = _isAutoComp;
        isCollect = _isCollect;

        require(
            _checkPath(_earnedToUpPath0, _earnedToUpPath1, earnedAddress, UPAddress),
            "invalid _earnedToUpPath"
        );
        earnedToUpPath0 = _earnedToUpPath0;
        earnedToUpPath1 = _earnedToUpPath1;

        require(
            _checkPath(_earnedToToken0Path0, _earnedToToken0Path1, earnedAddress, token0Address),
            "invalid _earnedToToken0Path"
        );
        earnedToToken0Path0 = _earnedToToken0Path0;
        earnedToToken0Path1 = _earnedToToken0Path1;

        require(
            token0Address == token1Address || _checkPath(_earnedToToken1Path0, _earnedToToken1Path1, earnedAddress, token1Address),
            "invalid _earnedToToken1Path"
        );
        earnedToToken1Path0 = _earnedToToken1Path0;
        earnedToToken1Path1 = _earnedToToken1Path1;

        require(_buyBackRate <= buyBackRateUL, "invalid buybackRate");
        require(_controllerFee <= controllerFeeUL, "invalid controllerFee");
        require(_entranceFeeFactor >= entranceFeeFactorLL && _entranceFeeFactor <= entranceFeeFactorMax, "invalid entranceFee");
        require(_withdrawFeeFactor >= withdrawFeeFactorLL && _withdrawFeeFactor <= withdrawFeeFactorMax, "invalid withdrawFee");
        buyBackRate = _buyBackRate;
        controllerFee = _controllerFee;
        entranceFeeFactor = _entranceFeeFactor;
        withdrawFeeFactor = _withdrawFeeFactor;
    }
}
