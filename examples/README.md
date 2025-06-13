# Fibonacci
```
make assemble ARGS="./examples/fib.asm"
make cpu_simulator ARGS="--print-final-ram 256 30 ./examples/fib.bin"
```


## Triangle Area
```
make assemble ARGS="./examples/tri_area.asm"
make cpu_simulator ARGS="--print-final-ram 256 1 ./examples/tri_area.bin"
```

# Factorial
```
make assemble ARGS="./examples/fac.asm"
make cpu_simulator ARGS="--print-final-ram 256 1 ./examples/fac.bin"
```

# Grid
```
make assemble ARGS="./examples/grid.asm"
make cpu_simulator ARGS="--display-ram 256 16 16 ./examples/grid.bin"
```