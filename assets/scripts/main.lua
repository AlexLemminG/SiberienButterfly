print("Butterfly.main module begin")

print("Before loading test module from main")
local testmodule = require("test")
print("After loading test module from main")

print("Before calling test module function from main")
testmodule.PrintHello()
print("After calling test module function from main")

print("Butterfly.main module end")

