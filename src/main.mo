import Nat "mo:base/Nat";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";

import Types "Types";
import ICRC "ICRC";

shared ({ caller }) actor class Minter(_quoteID : Text, _stathID : Text, _price_feed_id : Text, _solvency_factor : Nat, _ckBTC_principal_id : Text) = this {

  type PriceFeed = Types.XRC;
  type Subaccount = Types.Subaccount;
  type ICRC = Types.ICRC;
  type Result<Err, Ok> = Result.Result<Text, Text>;
  type Price = {
    price : Nat;
    price_decimal : Nat;
  };
  type PriceResult = {
    #Ok : Price;
    #Err : Text;
  };
  type Details = {
    btc_price : Nat;
    price_decimal : Nat;
    pool_balance : Nat;
    pool_valuation : Nat;
    quote_total_supply : Nat;
    stath_total_supply : Nat;
  };
  type Essentials = {
    #Ok : Details;
    #Err : Text;
  };

  stable var incentiveFactor = 0; //incentiveFactor in percentage * 10 ** 18;
  stable var solvencyFactor = 0; //solvencyFactor in percentage * 10 ** 18

  // deployed is set to true once using the init function
  stable var deployed = false;
  stable var bootStrapPhase = true;
  stable var admin = caller;

  stable var quote_ID = _quoteID; //canisterID for deployed $QUOTE canisterID
  stable var stath_ID = _stathID; //canisterID for deployed $STATH canisterID
  stable var quote : ICRC = actor (_quoteID);
  stable var stath : ICRC = actor (_stathID);

  //canisterID for ckBTc
  stable let priceFeedID = _price_feed_id; //canisterID for xrc deployed on mainnet
  stable let ckBTC_ID = _ckBTC_principal_id; //initailising tokens using the icrc token interface
  stable let ckBTC : ICRC = actor (ckBTC_ID);
  stable let oracle : PriceFeed = actor (priceFeedID);

  public func init() : async () {
    assert (deployed == false);

    deployed := true;
  };

  // incentiveFactor is a measure of the rewards in $STATH used to incentives the burning of quote when solvencyFactor has been subceeded
  private func _incentiveValue(liquidityDifference : Nat, amountIn : Nat) : Nat {
    let ivalue = (incentiveFactor * liquidityDifference * amountIn) / 10 ** 18;
    return ivalue;
  };

  //sendIn and sendOut functions used for transferring tokens in and out of the pool
  //Note:SendIn functions for $QUOTE and $STATH results in burning the  sent tokens and sendOut in minting
  //this is due to that fact that this canister ID is set as the minting account for both tokens
  //isTransfer is set as true  only for ckBTC transactions
  private func _sendIn(tokenID : Text, isTransfer : Bool, from : Principal, _subaccount : ?Subaccount, amount : Nat) : async () {
    let token : Types.ICRC = actor (tokenID);
    let actorAddress = Principal.fromText("");
    var fee = 0;
    if (isTransfer) {
      fee := await token.icrc1_fee();
    };
    let tx = await ckBTC.icrc2_transfer_from({
      spender_subaccount = null;
      from = {
        owner = from;
        subaccount = _subaccount;
      };
      to = {
        owner = actorAddress;
        subaccount = null;
      };
      amount = amount;
      fee = ?fee;
      memo = null;
      created_at_time = null;

    });
    let result = switch (tx) {
      case (#Ok(result)) { true };
      case (#Err(err)) { false };
    };
    assert (result);
  };

  private func _sendOut(tokenID : Text, isTransfer : Bool, to : Principal, _subaccount : ?Subaccount, amount : Nat) : async () {
    let token : Types.ICRC = actor (tokenID);
    var fee = 0;
    if (isTransfer) {
      fee := await token.icrc1_fee();
    };
    let tx = await token.icrc1_transfer({
      from_subaccount = null;
      to = { owner = to; subaccount = _subaccount };
      amount = amount;
      fee = ?fee;
      memo = null;
      created_at_time = null;
    });
    let result = switch (tx) {
      case (#Ok(result)) { true };
      case (#Err(err)) { false };
    };
    assert (result);
  };

  private func _takeFee(amount : Nat, fee : Nat) : Nat {
    let diff = amount * fee / 100000;
    return amount - diff;
  };
  private func _percent(amount : Nat, percent : Nat) : Nat {
    return (amount * percent) / 100000;
  };

  //_getExchangeRate fetches the current rate of BTC from the xrc canister and returns either the Result or an Error
  private func _getExchangeRate() : async PriceResult {
    ExperimentalCycles.add(1_000_000_000);
    let rateResult = await oracle.get_exchange_rate({
      base_asset = {
        symbol = "BTC";
        class_ = #Cryptocurrency;
      };
      quote_asset = {
        symbol = "USD";
        class_ = #FiatCurrency;
      };
      timestamp = null;
    });

    let result = switch (rateResult) {
      case (#Ok(exchangeRate)) {
        exchangeRate;
      };
      case (#Err(err)) {
        return #Err("Error Occured ");
      };
    };

    #Ok({
      price = Nat64.toNat(result.rate);
      price_decimal = Nat32.toNat(result.metadata.decimals);
    });
  };

  //_getessentials returns all essential details nnede for any minting or burning action within the canister ,these include

  /*
    btc_price
    price_decimal i.e the price always return as a multiple of 10 raised o the power of the price decimal ,this is done to avoid float;
    pool_balance i.e amount of ckBTC within the Pool;
    pool_valuation i.e the value of total amount of ckBTC within the pool
    quotetotalsupply :totalSupply of quote token;
    stath_total_supply :totalSupply of stath token;
  */
  private func _getEssentials() : async Essentials {
    let rateResult = await _getExchangeRate();

    let result : Price = switch (rateResult) {
      case (#Ok(price)) { price };
      case (#Err(err)) { return #Err(err) };
    };
    let price = result.price;
    let price_decimal = result.price_decimal;
    let pool_balance = await ckBTC.icrc1_balance_of({
      owner = Principal.fromActor(this);
      subaccount = null;
    });

    return #Ok({
      btc_price = result.price;
      price_decimal = result.price_decimal;
      pool_balance = pool_balance;
      pool_valuation = (pool_balance * price) / 10 ** price_decimal;
      quote_total_supply = await quote.icrc1_total_supply();
      stath_total_supply = await stath.icrc1_total_supply();
    });
  };

  //minting of stath
  private func _mintSTATH(caller : Principal, _subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    let details : Details = switch (await _getEssentials()) {
      case (#Ok(essentials)) { essentials };
      case (#Err(err)) { return #err(err) };
    };

    //quote_valuation is the amount of BTC equivalent in price to the totalSupply of Quote
    let quote_valuation = (details.quote_total_supply * (10 ** details.price_decimal)) / details.btc_price;

    // when the pool_balance is lower than quote_valuation a bootstrap mint occurs instead
    if (details.pool_balance < quote_valuation) {
      return await _bootStrapMint(caller, _subaccount, amount);
    };
    let amount_to_mint : Nat = (amount * details.stath_total_supply) / (details.pool_balance - quote_valuation);
    let amount_value = (amount_to_mint * details.btc_price) / 10 ** details.price_decimal;

    //Pool cannot exceed the maximum amount of leverage which is 8x
    if ((details.quote_total_supply * 8) < (details.pool_valuation + amount_value)) {
      return #err("Exceeded Collateral Maximum");
    };
    let sendInTx = await _sendIn(ckBTC_ID, true, caller, _subaccount, amount);
    let mintTx = await _sendOut(stath_ID, false, caller, _subaccount, amount_value);
    return #ok("Successful");
  };
  //Used when pool on initailDeployment to raise Sufficient backing for the minting of $QUOTE
  private func _bootStrapMint(caller : Principal, _subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    let actorAddress = Principal.fromText("");
    let fee = await ckBTC.icrc1_fee();
    let sendInTX = await _sendIn(ckBTC_ID, true, caller, _subaccount, amount);
    let mintTx = await _sendOut(stath_ID, false, caller, _subaccount, amount);
    return #ok("Successful");

  };

  private func _mintQUOTE(caller : Principal, _subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    let details : Details = switch (await _getEssentials()) {
      case (#Ok(essentials)) { essentials };
      case (#Err(err)) { return #err(err) };
    };

    let amount_equivalent = amount * details.btc_price / 10 ** details.price_decimal;
    //transaction fails if $QUOTE is paseed minCollateral i.e each amount of $QUOTE is not backed by 4x the price equivalent in BTC
    if ((details.pool_valuation / 4) < (details.quote_total_supply + amount_equivalent)) {
      return #err("Insufficient Collateral in Pool");
    };
    let amount_after_fees = _takeFee(amount_equivalent, 500);
    let sendInTx = await _sendIn(ckBTC_ID, true, caller, _subaccount, amount);
    let mintTx = await _sendOut(quote_ID, false, caller, _subaccount, amount_after_fees);
    return #ok("Succesful");
  };

  private func _burnSTATH(caller : Principal, _subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    let details : Details = switch (await _getEssentials()) {
      case (#Ok(essentials)) { essentials };
      case (#Err(err)) { return #err(err) };
    };
    let quote_valuation = (details.quote_total_supply * (10 ** details.price_decimal)) / details.btc_price;

    let amount_equivalent : Nat = (amount * (details.pool_balance - quote_valuation)) / details.stath_total_supply;

    let poolValuationAfter : Nat = ((details.pool_balance - amount_equivalent) * details.btc_price) / 10 ** details.price_decimal;

    //if $QUOTE minCollateral is subceeded i.e less than 4x the price equivalent totalSupply are in the pool transaction fails
    if ((details.quote_total_supply * 4) < poolValuationAfter) {
      return #err("Minimum Collateral Subceeded");
    };
    let amount_after_fees = _takeFee(amount_equivalent, 10 ** 2);
    let burnTx = await _sendIn(stath_ID, false, caller, _subaccount, amount);
    let sendOutTx = await _sendOut(ckBTC_ID, false, caller, _subaccount, amount_after_fees);
    return #ok("Succesful");
  };

  private func _burnQUOTE(caller : Principal, _subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    let details : Details = switch (await _getEssentials()) {
      case (#Ok(essentials)) { essentials };
      case (#Err(err)) { return #err(err) };
    };
    let amount_equivalent = (amount * (10 ** details.price_decimal)) / details.btc_price;
    let amount_after_fees = _takeFee(amount_equivalent, 500);
    let burnTx = await _sendIn(quote_ID, false, caller, _subaccount, amount);
    let sendOutTx = await _sendOut(ckBTC_ID, false, caller, _subaccount, amount_after_fees);
    return #ok("Successful");
  };

  private func _iBurnQUOTE(caller : Principal, _subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    let details : Details = switch (await _getEssentials()) {
      case (#Ok(essentials)) { essentials };
      case (#Err(err)) { return #err(err) };
    };
    let threshhold = _percent(details.quote_total_supply, solvencyFactor);
    if (threshhold < details.pool_valuation) {
      return #err("Solvency Threshhold not Subceeded");
    };
    let quote_valuation = (details.quote_total_supply * 10 ** details.price_decimal) / details.btc_price;
    let amount_equivalent : Nat = (amount * (details.pool_balance - quote_valuation)) / details.quote_total_supply;
    let amount_after_fees = _takeFee(amount_equivalent, 500);
    let burnTX = await _sendIn(quote_ID, false, caller, _subaccount, amount);
    let sendOutTx = await _sendOut(ckBTC_ID, false, caller, _subaccount, amount_after_fees);
    let ivalue = _incentiveValue(threshhold - details.pool_valuation, amount);
    let mintTx = await _sendOut(stath_ID, false, caller, _subaccount, ivalue);
    return #ok("Succesfull");
  };

  public shared ({ caller }) func mintSTATH(_subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    assert (bootStrapPhase == false);
    let Tx = await _mintSTATH(caller, _subaccount, amount);
  };

  public shared ({ caller }) func bootStrapMint(_subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    assert (bootStrapPhase == true);
    let Tx = await _bootStrapMint(caller, _subaccount, amount);
  };

  public shared ({ caller }) func mintQUOTE(_subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    assert (bootStrapPhase == false);
    let Tx = await _mintQUOTE(caller, _subaccount, amount);
  };

  public shared ({ caller }) func burnSTATH(_subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    assert (bootStrapPhase == false);
    let Tx = await _burnSTATH(caller, _subaccount, amount);
  };

  public shared ({ caller }) func burnQUOTE(_subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    assert (bootStrapPhase == false);
    let Tx = await _burnQUOTE(caller, _subaccount, amount);

  };

  public shared ({ caller }) func iBurnQUOTE(_subaccount : ?Subaccount, amount : Nat) : async Result<Text, Text> {
    assert (bootStrapPhase == false);
    let Tx = await _iBurnQUOTE(caller, _subaccount, amount);
  };

  public shared ({ caller }) func setPhase(phase : Bool) : async () {
    assert (caller == admin);
    bootStrapPhase := phase;
  };
  public shared ({ caller }) func setIncentiveFactor(factor : Nat) : async () {
    assert (caller == admin);
    incentiveFactor := factor;
  };

  public shared ({ caller }) func setSolvencyFactor(factor : Nat) : async () {
    assert (caller == admin);
    solvencyFactor := factor;
  };

  public shared ({ caller }) func setNewAdmin(newAdmin : Principal) : async () {
    assert (caller == admin);
    admin := newAdmin;
  };

  public query func getIncentiveFactor() : async Nat {
    return incentiveFactor;
  };

  public query func getSolvencyFactor() : async Nat {
    return solvencyFactor;
  };
};