// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IMarsSwapPair.sol";
import "../interfaces/IMarsSwapFactory.sol";

library MarsSwapLibrary {
    using SafeMath for uint256;

    // Returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(
            tokenA != tokenB,
            "MarsSwapLibrary::sortTokens: Identical addresses"
        );
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(
            token0 != address(0),
            "MarsSwapLibrary::sortTokens: Zero address"
        );
    }

    // Calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        factory,
                        keccak256(abi.encodePacked(token0, token1)),
                        hex"a37e703be319900c31352c241c70ef5429ba936b454e7c63e64e64708d8ab360" // init code hash
                    )
                )
            )
        );
    }

    // Fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    )
        internal
        view
        returns (
            address pair,
            uint256 reserveA,
            uint256 reserveB
        )
    {
        (address token0, ) = sortTokens(tokenA, tokenB);

        pair = pairFor(factory, tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) =
            IMarsSwapPair(pair).getReserves();

        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    // Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "MarsSwapLibrary::quote: Insufficient amount");
        require(
            reserveA > 0 && reserveB > 0,
            "MarsSwapLibrary::quote: Insufficient liquidity"
        );
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // Given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeScale
    ) internal pure returns (uint256 amountOut) {
        require(
            amountIn > 0,
            "MarsSwapLibrary::getAmountOut: Insufficient input amount"
        );
        require(
            reserveIn > 0 && reserveOut > 0,
            "MarsSwapLibrary::getAmountOut: Insufficient liquidity"
        );
        uint256 amountInWithFee = amountIn.mul(feeScale);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // Given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeScale
    ) internal pure returns (uint256 amountIn) {
        require(
            amountOut > 0,
            "MarsSwapLibrary::getAmountIn: Insufficient output amount"
        );
        require(
            reserveIn > 0 && reserveOut > 0,
            "MarsSwapLibrary::getAmountIn: Insufficient liquidity"
        );
        uint256 numerator = reserveIn.mul(amountOut).mul(1000);
        uint256 denominator = reserveOut.sub(amountOut).mul(feeScale);
        amountIn = (numerator / denominator).add(1);
    }

    // Performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(
            path.length >= 2,
            "MarsSwapLibrary::getAmountsOut: Invalid path"
        );
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (address pair, uint256 reserveIn, uint256 reserveOut) =
                getReserves(factory, path[i], path[i + 1]);
            (, , uint256 feeScale) = IMarsSwapFactory(factory).fee(pair);
            amounts[i + 1] = getAmountOut(
                amounts[i],
                reserveIn,
                reserveOut,
                feeScale
            );
        }
    }

    // Performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address factory,
        uint256 amountOut,
        address[] memory path
    ) internal view returns (uint256[] memory amounts) {
        require(
            path.length >= 2,
            "MarsSwapLibrary::getAmountsIn: Invalid path"
        );
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (address pair, uint256 reserveIn, uint256 reserveOut) =
                getReserves(factory, path[i - 1], path[i]);
            (, , uint256 feeScale) = IMarsSwapFactory(factory).fee(pair);
            amounts[i - 1] = getAmountIn(
                amounts[i],
                reserveIn,
                reserveOut,
                feeScale
            );
        }
    }
}
