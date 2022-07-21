// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface IRewardsDistributor {
    function setBeneficiaries(
        address[] memory _beneficiaryAddresses,
        uint256[] memory _beneficiaryRewardFactors
    ) external;

    function distributeRewards(address token) external;

    function beneficiaryAddresses(uint256 id) external view returns (address);

    function beneficiaryRewardFactors(uint256 id) external view returns (uint256);
}