import Types "Types";

//Note this is a just sample canister contract for the xrc priecFeed ,the price of BTC is hardcoded at 30K
//the official xrc will be used for production
actor Oracle {

    let result : Types.GetExchangeRateResult = #Ok({
        base_asset = {
            symbol = "BTC";
            class_ = #Cryptocurrency;
        };
        quote_asset = {
            symbol = "USD";
            class_ = #FiatCurrency;
        };
        timestamp = null;
        rate = 30000;
        metadata = {
            decimals = 0;
            base_asset_num_received_rates = 1;
            base_asset_num_queried_sources = 1;
            quote_asset_num_received_rates = 1;
            quote_asset_num_queried_sources = 1;
            standard_deviation = 1;
            forex_timestamp = null;
        };
    });

    public shared ({ caller }) func get_exchange_rate(params : Types.GetExchangeRateRequest) : async Types.GetExchangeRateResult {
        return result;
    };
};