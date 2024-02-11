/**
 * Module     : types.mo
 * Copyright  : 2021 Rocklabs
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Rocklabs <hello@rocklabs.io>
 * Stability  : Experimental
 */

import Time "mo:base/Time";
import P "mo:base/Prelude";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";

module {
    /// Update call operations

    public type Operation = {
        #mint;
        #burn;
        #transfer;
        #transferFrom;
        #approve;
    };
    public type TransactionStatus = {
        #succeeded;
        #inprogress;
        #failed;
    };
    /// Update call operation record fields
    public type TxRecord = {
        caller : ?Principal;
        op : Operation;
        index : Nat;
        from : Principal;
        to : Principal;
        amount : Nat;
        fee : Nat;
        timestamp : Time.Time;
        status : TransactionStatus;
    };

    public type RoundData = {
        roundId : Nat;
        answer : Nat;
        startedAt : Nat;
        updatedAt : Nat;

    };

    public type Aggregator = actor {
        version : query () -> async Nat;
        decimal : query () -> async Nat;
        description : () -> async Text;
        getRoundData : (Nat) -> async RoundData;
        latestRoundData : () -> async RoundData

    };

    public type BlockIndex = Nat;
    public type Subaccount = Blob;
    // Number of nanoseconds since the UNIX epoch in UTC timezone.
    public type Timestamp = Nat64;
    // Number of nanoseconds between two [Timestamp]s.
    public type Tokens = Nat;
    public type TxIndex = Nat;

    public type Account = {
        owner : Principal;
        subaccount : ?Subaccount;
    };

    public type TransferArg = {
        from_subaccount : ?Subaccount;
        to : Account;
        amount : Tokens;
        fee : ?Tokens;
        memo : ?Blob;
        created_at_time : ?Timestamp;
    };

    public type TransferError = {
        #BadFee : { expected_fee : Tokens };
        #BadBurn : { min_burn_amount : Tokens };
        #InsufficientFunds : { balance : Tokens };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #TemporarilyUnavailable;
        #Duplicate : { duplicate_of : BlockIndex };
        #GenericError : { error_code : Nat; message : Text };
    };

    public type TransferResult = {
        #Ok : BlockIndex;
        #Err : TransferError;
    };

    // The value returned from the [icrc1_metadata] endpoint.
    public type MetadataValue = {
        #Nat : Nat;
        #Int : Int;
        #Text : Text;
        #Blob : Blob;
    };

    public type ApproveArgs = {
        from_subaccount : ?Subaccount;
        spender : Account;
        amount : Tokens;
        expected_allowance : ?Tokens;
        expires_at : ?Timestamp;
        fee : ?Tokens;
        memo : ?Blob;
        created_at_time : ?Timestamp;
    };

    public type ApproveError = {
        #BadFee : { expected_fee : Tokens };
        #InsufficientFunds : { balance : Tokens };
        #AllowanceChanged : { current_allowance : Tokens };
        #Expired : { ledger_time : Nat64 };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : BlockIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    public type ApproveResult = {
        #Ok : BlockIndex;
        #Err : ApproveError;
    };

    public type AllowanceArgs = {
        account : Account;
        spender : Account;
    };

    public type Allowance = {
        allowance : Tokens;
        expires_at : ?Timestamp;
    };

    public type TransferFromArgs = {
        spender_subaccount : ?Subaccount;
        from : Account;
        to : Account;
        amount : Tokens;
        fee : ?Tokens;
        memo : ?Blob;
        created_at_time : ?Timestamp;
    };

    public type TransferFromResult = {
        #Ok : BlockIndex;
        #Err : TransferFromError;
    };

    public type TransferFromError = {
        #BadFee : { expected_fee : Tokens };
        #BadBurn : { min_burn_amount : Tokens };
        #InsufficientFunds : { balance : Tokens };
        #InsufficientAllowance : { allowance : Tokens };
        #TooOld;
        #CreatedInFuture : { ledger_time : Nat64 };
        #Duplicate : { duplicate_of : BlockIndex };
        #TemporarilyUnavailable;
        #GenericError : { error_code : Nat; message : Text };
    };

    public type ICRC = actor {

        icrc1_decimals : shared query () -> async Nat8;

        icrc1_total_supply : query () -> async Tokens;

        icrc1_fee : shared query () -> async Tokens;

        icrc1_balance_of : shared query (Account) -> async Tokens;

        icrc1_transfer : shared (TransferArg) -> async TransferResult;

        icrc2_transfer_from : shared (TransferFromArgs) -> async TransferFromResult;
    };

    type TxReceipt = Result.Result<Nat, { #InsufficientBalance; #InsufficientAllowance; #Unauthorized }>;

    public type XRC = actor {
        get_exchange_rate : shared GetExchangeRateRequest -> async GetExchangeRateResult;
    };

    public type AssetClass = { #Cryptocurrency; #FiatCurrency };

    public type Asset = {
        symbol : Text;
        class_ : AssetClass;
    };

    public type GetExchangeRateRequest = {
        base_asset : Asset;
        quote_asset : Asset;
        timestamp : ?Nat64;
    };

    public type GetExchangeRateResult = {
        #Ok : ExchangeRate;
        #Err : ExchangeRateError;
    };

    public type ExchangeRateMetadata = {
        decimals : Nat32;
        base_asset_num_received_rates : Nat64;
        base_asset_num_queried_sources : Nat64;
        quote_asset_num_received_rates : Nat64;
        quote_asset_num_queried_sources : Nat64;
        standard_deviation : Nat64;
        forex_timestamp : ?Nat64;
    };

    public type ExchangeRate = {
        base_asset : Asset;
        quote_asset : Asset;
        timestamp : ?Nat64;
        rate : Nat64;
        metadata : ExchangeRateMetadata;
    };

    public type ExchangeRateError = {
        //// Returned when the canister receives a call from the anonymous principal.
        #AnonymousPrincipalNotAllowed;
        //// Returned when the canister is in process of retrieving a rate from an exchange.
        #Pending;
        /// Returned when the base asset rates are not found from the exchanges HTTP outcalls.
        #CryptoBaseAssetNotFound;
        /// Returned when the quote asset rates are not found from the exchanges HTTP outcalls.
        #CryptoQuoteAssetNotFound;
        /// Returned when neither forex asset is found.
        #ForexAssetsNotFound;
        /// Returned when a rate for the provided forex asset could not be found at the provided timestamp.
        #ForexInvalidTimestamp;
        /// Returned when the forex base asset is found.
        #ForexBaseAssetNotFound;
        /// Returned when the forex quote asset is found.
        #ForexQuoteAssetNotFound;
        /// Returned when the stablecoin rates are not found from the exchanges HTTP outcalls needed for computing a crypto/fiat pair.
        #StablecoinRateNotFound;
        /// Returned when there are not enough stablecoin rates to determine the forex/USDT rate.
        #StablecoinRateTooFewRates;
        /// Returned when the stablecoin rate is zero.
        #StablecoinRateZeroRate;
        /// Returned when the caller is not the CMC and there are too many active requests.
        #RateLimited;
        /// Returned when the caller does not send enough cycles to make a request.
        #NotEnoughCycles;
        /// Returned when the canister fails to accept enough cycles.
        #FailedToAcceptCycles;
        //// Returned if too many collected rates deviate substantially.
        #InconsistentRatesReceived;
        /// Until candid bug is fixed, new errors after launch will be placed here.
        #Other : {
            /// The identifier for the error that occurred.
            code : Nat32;
            /// A description of the error that occurred.
            description : Text;
        };
    };

    public func unwrap<T>(x : ?T) : T = switch x {
        case null { P.unreachable() };
        case (?x_) { x_ };
    };
};