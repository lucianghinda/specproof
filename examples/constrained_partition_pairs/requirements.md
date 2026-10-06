# Account eligibility requirements

An account may be opened only by an adult. Minors cannot have a business
account. Both supported account types (`"personal"` and `"business"`) and
countries (`"ro"` and `"de"`) are otherwise valid. Eligibility is true exactly
when age is at least 18; account type and country do not change that result.

The restriction on business accounts justifies forbidding the whole `minor`
partition with `account: "business"`. The age-based eligibility rule supplies
expected outputs to the example tests. Suggestions provide inputs only and
are not an output oracle.
