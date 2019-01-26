for i in {1..5}; do
    local testResult = truffle test
    if testResult == false; then
    trap "Test Failed" ERR
    fi
done
