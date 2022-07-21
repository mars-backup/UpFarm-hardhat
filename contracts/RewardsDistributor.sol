// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interfaces/IRewardsDistributor.sol";
import "./refs/CoreRef.sol";
import "./interfaces/IWBNB.sol";
import "./libs/TransferHelper.sol";

contract RewardsDistributor is CoreRef, IRewardsDistributor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable wbnbAddress;
    address [] public override beneficiaryAddresses;
    uint256 [] public override beneficiaryRewardFactors;

    event SetBeneficiaries(
        address[],
        uint256[]
    );

    event DistributeRewards(address token, uint256 rewardsAmt);

    constructor(
        address core_,
        address _wbnb
    ) public CoreRef(core_) {
        wbnbAddress = _wbnb;
    }

    function setBeneficiaries(
        address[] memory _beneficiaryAddresses,
        uint256[] memory _beneficiaryRewardFactors
    ) external override onlyGovernor {
        require(
            _beneficiaryAddresses.length == _beneficiaryRewardFactors.length,
            "TimelockController: arrays diff length"
        );

        uint256 rewardFactorsTotal = 0;
        for (uint8 i = 0; i < _beneficiaryRewardFactors.length; i++) {
            rewardFactorsTotal = rewardFactorsTotal.add(_beneficiaryRewardFactors[i]);
        }

        require(
            rewardFactorsTotal <= 10000,
            "TimelockController: rewardFactorsTotal must be max 1000"
        );

        beneficiaryAddresses = _beneficiaryAddresses;
        beneficiaryRewardFactors = _beneficiaryRewardFactors;

        emit SetBeneficiaries(beneficiaryAddresses, beneficiaryRewardFactors);
    }

    function distributeRewards(address token)
        external
        override
        onlyGuardianOrGovernor
    {
        uint256 rewardsAmt = IERC20(token).balanceOf(address(this));
        require(rewardsAmt > 0, "token balance zero");

        if (token == wbnbAddress) {
            IWBNB(token).withdraw(rewardsAmt);
            for (uint8 j = 0; j < beneficiaryAddresses.length; j++) {
                uint256 amt = rewardsAmt.mul(beneficiaryRewardFactors[j]).div(10000);
                if (amt > 0) {
                    TransferHelper.safeTransferETH(beneficiaryAddresses[j], amt);
                }
            }
        } else {
            for (uint8 j = 0; j < beneficiaryAddresses.length; j++) {
                IERC20(token).safeTransfer(
                    beneficiaryAddresses[j],
                    rewardsAmt.mul(beneficiaryRewardFactors[j]).div(10000)
                );
            }
        }
        emit DistributeRewards(token, rewardsAmt);
    }

    receive() external payable {}
}