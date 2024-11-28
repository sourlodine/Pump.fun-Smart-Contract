// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

// Libraries
import {Constants} from "./Constants.sol";
import {Errors} from "./Errors.sol";

/// @title Library for verifying and decoding Uniswap callbacks.
/// @author Axicon Labs Limited
library CallbackLib {
    // Defining characteristics of a Uni V3 pool
    struct PoolFeatures {
        address token0;
        address token1;
        uint24 fee;
    }

    // Data sent by pool in mint/swap callbacks used to validate the pool and send back requisite tokens
    struct CallbackData {
        PoolFeatures poolFeatures;
        address payer;
    }

    /// @notice Verifies that a callback came from the canonical Uniswap pool with a claimed set of features.
    /// @param sender The address initiating the callback and claiming to be a Uniswap pool
    /// @param factory The address of the canonical Uniswap V3 factory
    /// @param features The features `sender` claims to contain
    function validateCallback(
        address sender,
        address factory,
        PoolFeatures memory features
    ) internal pure {
        // compute deployed address of pool from claimed features and canonical factory address
        // then, check against the actual address and verify that the callback came from the real, correct pool
        if (
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                factory,
                                keccak256(abi.encode(features)),
                                Constants.V3POOL_INIT_CODE_HASH
                            )
                        )
                    )
                )
            ) != sender
        ) revert Errors.InvalidUniswapCallback();
    }
}