/usr/local/bin/mina ledger export staking-epoch-ledger > YOUR_LEDGER_DIRECTORY/staking-epoch-ledger.json
/usr/local/bin/mina ledger export next-epoch-ledger > YOUR_LEDGER_DIRECTORY/next-epoch-ledger.json
/usr/local/bin/mina ledger hash --ledger-file YOUR_LEDGER_DIRECTORY/staking-epoch-ledger.json | xargs -I % cp YOUR_LEDGER_DIRECTORY/staking-epoch-ledger.json YOUR_LEDGER_DIRECTORY/%.json
/usr/local/bin/mina ledger hash --ledger-file YOUR_LEDGER_DIRECTORY/next-epoch-ledger.json | xargs -I % cp YOUR_LEDGER_DIRECTORY/next-epoch-ledger.json YOUR_LEDGER_DIRECTORY/%.json
