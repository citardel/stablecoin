# USDQ Stablecoin

DollarQuote stablecoin (symbol $USDQ) is the first decentralized algorithmic stablecoin on the Internet Computer Network that is backed by Chain Key Bitcoin (ckBTC) which is a secure form of bitcoin on the Internet Computer network that can be retrieved in a ratio of 1:1 on the bitcoin network by utilising the threshold ECDSA.<br>

## Mechanism

The $USDQ token is an ICRC token that is minted by depositing any amount of ckBTC (no minimum amount set for now) into the QuoteMinter Canister and the price equivalent of that amount in $USD is minted and sent to the depositor <br><br>

Cryptocurrencies are currently very volatile hence if the deposited amount of ckBTC loses its value due to price drop the minted tokens become devalued and hence no longer pegged to a dollar ,this risk is commonly averted by requiring users to deposit a greater value of the volatile asset for a lesser value of token.

 The $USDQ token functions by being overcollateralized by ckBTC within a particular range currently 4x as low_range and 8x as high_range (this is currently hard coded but can be made more dynamic).<br>

QuoteMinter Canister uses a unique approach whereby other users (holders of $STATH) provide this excess liquidity needed as Overcollateral for the minted tokens .<br>


$STATH is minted by calling the mintSTATH method in the QuoteMinter Canister which initiates a deposit of a specified amount of ckBTC into the QuoteMinter Canister and then the equivalent amount of $STATH is minted ,
>The value of $STATH at any point in time is determined by the total amount of ckBTC within the QuoteMinter Canister minus the amount just equivalent in USD to the entire supply of $USDQ token<br>

**$STATH** holders are incentivized by the fees collected during minting and burning of $USDQ and also since $USDQ is an __ICRC__ token ,the fees for all transactions are burnt hence reducing the total supply of the token on every transaction which would also be to the advantage of $STATH holders .


## Features of Quote Stablecoin

* ### Collateral Range <br>
   when the equivalent amount of price of BTC falls such that the value of the total ckBTC in the QuoteMinter Canister in USD is less than 4x the total supply of $USDQ ,the following occurs
  * minting of Quote is halted 
  * Burning of Quote is halted
  
  >This is done to ensure that each minted quote token is sufficiently collateralized <br>

  When the price of BTC rises or total supply of $USDQ reduces such that the value in USD of the total ckBTC in the pool is greater than 8x the total supply of $USDQ,the minting of STATH is halted<br>

  >This is done to avoid over-saturation of rewards for $STATH holders and hence further incentivizing users to hold $STATH long term<br>


* ### Solvency Factor and Solvency Threshold<br>
   The __Solvency Factor__ in percentage is utilized together with the __Incentivization Factor__ to incentivize the burning of $USDQ.<br>
   The Solvency Factor is the percentage of the total Supply of QUOTE in which if the value of the entire ckBTC within the QuoteMinter cansiter falls below ,the pools is considered to be heading for Insolvency and this is mitigated through the use  of Incentivization Factor to incentivize the burning of $USDQ for ckBTC.
   >The Solvency Factor is currently set manually but can be made more automated taking into consideration factors like current market volatility <br>
   >The __Solvency  Threshold__ is equal to __Solvency Factor__ percentage of QUOTE total supply e.g a if total supply is 200 and solvency factor 150(* 10**18... decimal precison) the solvency threshold would be 300.
   <br>
* ### Incentivization Factor<br>
  The __Incentivization Factor__ is the measure of the amount of reward in $STATH to be given for burning a certain amount of $USDQ token when the __Solvency Threshold__ has been subceeded,this value is determined by few factors such as 
  * The difference of the Solvency Threshold value and the value of the entire ckBTC in the pool.
  * The amount of $USDQ token being burnt in the call
  >This creates a demand for $USDQ in the presence of a falling BTC price and users would be incentivized to burn $USDQ to receive the equal amount of ckBTC and be rewarded with $STATH.<br>
  >This incentivization factor is currently set manually but can be automated <br>

* ### Use of the Official Exchange Rate  Canister (XRC) <br>
  The QuoteMinter Canister utilizes the **[Exchange Rate Canister](https://internetcomputer.org/docs/current/developer-docs/integrations/exchange-rate/exchange-rate-canister)** created by **DFINITY** which provides Real-Time Exchange rate data for different assets pair through the HTTP outcalls  to fetch the accurate rate for the BTC/USD pair that would be utilised for different operations. This is currently deployed on the [uzr34 system subnet](https://dashboard.internetcomputer.org/subnet/uzr34-akd3s-xrdag-3ql62-ocgoh-ld2ao-tamcv-54e7j-krwgb-2gm4z-oqe) and has a canister ID __uf6dk-hyaaa-aaaaq-qaaaq-cai__ <br>


## Running the project locally
 
 the project contains three basic actors The QuoteMinter ,The Simple ICRC token Implementation and the Simple Oracle .

 * The QuoteMinter Canister includes all minting and burning details of both __$USDQ__ and __$STATH__ .
 * The ICRC serves as a reference to deploy an ICRC token that we would be as ckBTC locally .
 * The oracle canister is just asimple canister to imitate the exchange rate cansiter and the current price of BTC is hardcoded at $30,000.<br>

If you want to test the  project locally, you can use the following commands:
 
```bash
# to clone this repo
git clone "https://github.com/citardel/stablecoin"
cd stablecoin

# install all dependencies
npm install

#Start your local replica
dfx start 
```
  deploy the Oracle Canister
``` bash
#deploy Oracle Canister
dfx deploy Oracle 
# after deployment get cansiter ID and save it 
```

**To Deploy an ICRC token**<br>
you would need to deploy an ICRC token that you would be using as ckBTC,QUOTE and STATH and  aslo minting  a certain amount to yourself(for ckBTC);
[see this Guide on How to deploy an ICRC token](https://internetcomputer.org/docs/current/tutorials/developer-journey/level-4/4.2-icrc-tokens)<br>
__NOTE that You would  need to enable FEATURE_FLAGS = true to enable all icrc2 features__<br>
Copy the canister ID when done <br>

Or you can deploy the sample provided in the dfx file ,just paste this in your terminal and run 

```bash

  # get your principal identity 
     export MyID=$(dfx identity get-principal)
  
    # to deploy ckBTC
    dfx deploy CKBTC --argument "(record { initial_mints = vec {record {account = record {owner = principal \"${MyID}\";};amount =100000000000000000000000000 }}; minting_account = record{ owner = principal \"${MyID}\"}; token_name = \"CKBitcoin\"; token_symbol = \"ckBTC\"; decimals = 18; transfer_fee = 100000000 })"

```
  
  To launch STATH and QUOTE we would need the cansiter ID for the QuoteMinter and we havenot deployed that yet ,so we would just create an empty canister and and install code later 

  ```bash

  #create the empty canister for QuoteMinter and get the canister id
  dfx canister create Minter
   # create a variable and set it to this canister id 
    export QUOTE_MINTER_ID=paste the canisterid 

    #To deploy QUOTE
  dfx deploy QUOTE --argument "(record { initial_mints = vec {}; minting_account = record{ owner = principal \"${QUOTE_MINTER_ID}\"}; token_name = \"Quote\"; token_symbol = \"QUOTE\"; decimals = 18; transfer_fee : 100000000 })"

  # To deploy STATH 
    dfx deploy STATH --argument "(record { initial_mints = vec {}; minting_account = record{ owner = principal \"${QUOTE_MINTER_ID}\"}; token_name = \"Stath\"; token_symbol = \"STATH\"; decimals = 18; transfer_fee : 100000000 })"
  ```

**To deploy and run the QuoteMinter Canister**
```bash
      export PRICE_FEED_ID= "The cansiter Id of the deployed Oracle Canister"

   export SOLVENCY_FACTOR= 100_000_000_000

   export ck_BTC_PRINCIPAL= "The canister of the sample ckBTC you deployed you just deployed"

   export QUOTE_ID= "the canister id of QUOTE"

   export STATH_ID="The cansiter id of STATH"

   
  ```
  to deploy the QuoteMinter canister run

  ```bash

  dfx deploy Minter --argument '(
     \"${QUOTE_ID}\",
     \"${STATH_ID}\",
     \"${PRICE_FEED_ID}\",
     ${SOLVENCY_FACTOR},
    _ ${ck_BTC_PRINCIPAL}
  )'
  ```

  After Succesfull deployment call the init function to instantiate it<br>
  ```bash
   dfx canister call Minter init "()"
  ```

  deposit ckBTC to mint STATH as this would ensure that anyminted Quote is overcollateralized at minting time


  To depsosit ckBTC you would need to call the bootStrapMint to mint $STATH,from the amount you minted just deposit 100000000
  ```bash
  export AMOUNT = 
  dfx canister call  Minter bootStrapMint '(null;10000000)' 
```

 now end the bootstrap phase so quote can be minted 
```bash
  #end the bootstrapPhase so $USDQ can be minted

  dfx canister call Minter setPhase '(false)' 
  

  # Now to mint $USDQ,call mintQUOTE with 10000 ckBTC
 dfx canister call Minter mintQUOTE '(null;10000)'

  ```

currently deployed at 

 * [Minter:](#link)
 * [QUOTE:](#link)
 * [STATH:](#link)
  

  




