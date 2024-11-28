// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Custom Errors library.
/// @author Axicon Labs Limited
library Errors {
    /// Errors are alphabetically ordered

    /// @notice The tokenID being burned during a roll is not the last index of the positionIdList (if provided)
    /// @dev We check this because we need to know where the old tokenId is, so we can replace it with the new one when checking collateral
    error BurnedTokenIdNotLastIndex();

    /// @notice Casting error
    /// @dev e.g. uint128(uint256(a)) fails
    error CastingError();

    /// @notice Collateral token has already been initialized
    error CollateralTokenAlreadyInitialized();

    /// @notice The amount of shares (or assets) deposited is too high
    error DepositTooLarge();

    /// @notice The Effective Liquidity is above the Threshold
    /// Effective liquidity measures how much new liquidity is minted relative to how much is already in the pool
    error EffectiveLiquidityAboveThreshold();

    /// @notice Attempted to withdraw/redeem more than available liquidity/used wrong function with open positions
    error ExceedsMaximumRedemption();

    /// @notice PanopticPool: List of option positions is invalid
    error InputListFail();

    /// @notice Emitted during a force exercise if the positions a user with open positions burns do not fully offset the decrease in collateral due to exercise fees
    error InsufficientCollateralDecrease();

    /// @notice Tick is not between MIN_TICK and MAX_TICK
    error InvalidTick();

    /// @notice A mint or swap callback was attempted from an address that did not match the canonical Uniswap V3 pool with the claimed features
    error InvalidUniswapCallback();

    /// @notice The result of a notional value conversion is too small (=0) or too large (>2^128-1)
    error InvalidNotionalValue();

    /// @notice Invalid TokenId parameter detected
    /// @param parameterType poolId=0, ratio=1, tokenType=2, risk_partner=3 , strike=4, width=5
    error InvalidTokenIdParameter(uint256 parameterType);

    /// @notice Invalid input in LeftRight library.
    error LeftRightInputError();

    /// @notice None of the forced exercised legs are exerciseable (they are all in-the-money)
    error NoLegsExercisable();

    /// @notice Not a valid option roll; some parameters differ that shouldn't (e.g. optionRatio, etc.)
    error NotATokenRoll();

    /// @notice PanopticPool: Position does not have enough collateral
    error NotEnoughCollateral();

    /// @notice max token amounts for position exceed 128 bits.
    error PositionTooLarge();

    /// @notice There is not enough liquidity to buy an option
    error NotEnoughLiquidity();

    /// @notice Position is not margin called and is therefore still solvent
    error NotMarginCalled();

    /// @notice Caller needs to be the owner
    /// @dev unauthorized access attempted
    error NotOwner();

    /// @notice The caller is not the Panoptic Pool
    error NotPanopticPool();

    /// @notice User's option balance is zero or does not exist
    error OptionsBalanceZero();

    /// @notice Options is not out-the-money (OTM)
    error OptionsNotOTM();

    /// @notice Uniswap pool has already been initialized in the SFPM
    error PoolAlreadyInitialized();

    /// @notice PanopticPool: Option position already minted
    error PositionAlreadyMinted();

    /// @notice PanopticPool: The user has open/active option positions.
    /// @dev for example, collateral cannot be moved if a user has active positions
    error PositionCountNotZero();

    /// @notice PanopticPool: Current tick not within range
    error PriceBoundFail();

    /// @notice Function has been called while reentrancy lock is active
    error ReentrantCall();

    /// @notice Too many positions open (above limit per account)
    error TooManyPositionsOpen();

    /// @notice Transfer failed
    error TransferFailed();

    /// @notice The tick range given by the strike price and width is invalid
    /// because the upper and lower ticks are not multiples of `tickSpacing`
    error TicksNotInitializable();

    /// @notice Under/Overflow has happened
    error UnderOverFlow();

    /// @notice Uniswap v3 pool itself has not been initialized and therefore does not exist.
    error UniswapPoolNotInitialized();

    /// @notice The Uniswap pool's `tickSpacing` is not defined by 2 * swapFee/100 and therefore is not supported.
    error UniswapPoolNotSupported();
}