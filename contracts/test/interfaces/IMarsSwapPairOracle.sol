// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "./IMarsSwapFactory.sol";
import "../libs/Decimal.sol";

interface IMarsSwapPairOracle {
    // ----------- Governor only state changing API -----------

    function setPeriod(uint256 period) external;

    function setFactory(address _factory) external;

    // ----------- State changing api -----------

    function update() external;

    function consult(uint256 amountIn)
        external
        view
        returns (Decimal.D256 memory amountOut);

    // ----------- Getters -----------

    function PERIOD() external view returns (uint256);

    function factory() external view returns (IMarsSwapFactory);
}
