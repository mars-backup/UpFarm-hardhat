// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./FixedPoint.sol";
import "../interfaces/IMarsSwapPair.sol";

library MarsSwapOracleLibrary {
    using FixedPoint for *;

    // Helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }

    // Produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(address pair)
        internal
        view
        returns (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        )
    {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IMarsSwapPair(pair).price0CumulativeLast();
        price1Cumulative = IMarsSwapPair(pair).price1CumulativeLast();

        // If time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) =
            IMarsSwapPair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // Subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // Addition overflow is desired
            // Counterfactual
            price0Cumulative +=
                uint256(FixedPoint.fraction(reserve1, reserve0)._x) *
                timeElapsed;
            // Counterfactual
            price1Cumulative +=
                uint256(FixedPoint.fraction(reserve0, reserve1)._x) *
                timeElapsed;
        }
    }
}
