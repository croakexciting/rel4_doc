## 1 seL4 startup

seL4 文档详细介绍了入门文档，我们可以参考

[Hello, World!](https://docs.sel4.systems/Tutorials/hello-world.html)

```
# download code
mkdir sel4-tutorials-manifest
cd sel4-tutorials-manifest
repo init -u https://github.com/seL4/sel4-tutorials-manifest
repo sync

# build
mkdir hello-world && cd hello-world
../init --tut hello-world
cd ../hello-world_build/
ninja

# run simulate
./simulate
```

[seL4Test](https://docs.sel4.systems/projects/sel4test/)

```
mkdir sel4test && cd sel4test
repo init -u https://github.com/seL4/sel4test-manifest.git
repo sync

mkdir build && cd build
../init-build.sh -DPLATFORM=spike
ninja

./simulate
```

当我们安装好环境后，上述两个例程都可以运行。

## 2 reL4 startup

运行 rel4test

```
mkdir rel4test && cd rel4test
repo init -u https://github.com/rel4team/sel4test-manifest.git -b v1.0
repo sync

cd rel4_kernel
make env
./build.py

cd build
./simulate
```

## 3 rust-sel4

完成环境安装后，我们就无需在 docker 中运行 rust sel4 example

> 目前 rust-sel4 运行的环境与 rel4 无关

```
git clone https://github.com/seL4/rust-root-task-demo.git
cd rust-root-task-demo

make run
```
