## 1 简介

目前 rel4 kernel 虽然已经去除所有 seL4 kernel 相关的 C 代码，但是仍然依赖 seL4 编译系统、linker scripts、一些汇编代码以及一些工具。

这样使得整个项目比较臃肿，如果能将 seL4 kernel 部分剥离，尽量使用 rust 编译系统和工具，那看起来会非常清爽。我准备做这样的尝试，计划从以下几部分先分析。

1. 分析 seL4 cmake 编译系统，理清编译流程，找到 kernel 和用户空间程序的边界。
2. 分析 linker scripts 和汇编代码，这部分需要移植到 rel4 kernel 中
3. 分析 seL4 目前使用的工具，理清这些工具的作用，确认是否需要替换

想象中，最终的目标是，在完全不依赖 seL4 kernel 的情况下，reL4 可以和 seL4 编译系统适配。

## 2 seL4 编译系统

与 Linux 不同，seL4 编译时会同时编译 kernel 和用户空间程序，并将其打包成一个镜像。我们的目的是找到 kernel 和 app 编译的边界，完全替换 seL4 kernel cmake 编译。

> 目前根据 seL4test 进行分析，没有了解 seL4 各个开发框架

### 2.1 编译脚本

当我们按照教程更新完 repo 后，repo 中路径如下

```
croak@cxyz:~/workspace/sel4test$ ls -l ./
total 16
drwxr-xr-x 11 croak croak 4096 Oct 20 19:35 build
lrwxrwxrwx  1 croak croak   37 Oct 20 15:01 easy-settings.cmake -> projects/sel4test/easy-settings.cmake
lrwxrwxrwx  1 croak croak   29 Oct 20 15:01 griddle -> tools/seL4/cmake-tool/griddle
lrwxrwxrwx  1 croak croak   35 Oct 20 15:01 init-build.sh -> tools/seL4/cmake-tool/init-build.sh
drwxr-xr-x 12 croak croak 4096 Oct 20 20:38 kernel
drwxr-xr-x  8 croak croak 4096 Oct 20 15:01 projects
drwxr-xr-x  5 croak croak 4096 Oct 20 15:01 tools
```

其中 init-build.sh 是编译脚本，我们执行如下命令进行编译

···
mkdir build && cd build
../init-build.sh -DPLATFORM=spike
ninja
···

执行完成后就会产生打包好的镜像。

init-build.sh 脚本本质上是 cmake 命令的 wrapper，我们只看最后三行即可

```
# If we don't have a CMakeLists.txt in the top level project directory then
# assume we use the project's directory tied to easy-settings.cmake and resolve
# that to use as the CMake source directory.
real_easy_settings="$(realpath $SCRIPT_PATH/easy-settings.cmake)"
project_dir="$(dirname $real_easy_settings)"
# Initialize CMake.
cmake -G Ninja "$@" -DSEL4_CACHE_DIR="$CACHE_DIR" -C "$project_dir/settings.cmake" "$project_dir"
```

由于 easy-settings.cmake 是执行 project/sel4test/easy-settings.cmake 的链接，因此 $project_dir=project/sel4test

cmake 命令就如最后一行，非常简单， "$@" 可以将我们自定义的 cmake variable 带入，比如上面的 -DPLATFORM=spike

可以看出，cmake 查找 $project_dir 也就是 project/sel4test 中的 CMakeLists.txt，sel4test 是一个用户空间程序，我们接着分析它的 CMakeLists.txt.

### 2.2 用户空间 CMakeLists

找到 sel4test 中的 CMakeLists，我们很容易的发现有三个重要的点

1. sel4_import_kernel()
   这个函数会触发 kernel 编译
   
2. elfloader_import_project()
   这个函数会触发 elfloader 编译
   
3. add_subdirectory(apps/sel4test-driver)
   sel4test 编译

sel4test 和 elfloader 的编译我们后面再详细分析，先继续往下看 kernel 编译

### 2.3 kernel 编译

正如上述所说，sel4_import_kernel() 触发了 kernel 编译。

> 用户空间通过 find_package(seL4 REQUIRED) 查找 kernel CMake module, 在 kernel 中定义了 Findsel4.cmake 文件，因此 find_package(seL4 REQUIRED) 会找到这个文件。这是 cmake module 相关的功能，有兴趣可以进一步了解。

sel4_import_kernel() 定义在 Findsel4 中，通过 find_package(seL4 REQUIRED) 引入 sel4test CMakeLists。这个函数中通过

```
macro(sel4_import_kernel)
    add_subdirectory(${KERNEL_PATH} ${CMAKE_BINARY_DIR}/kernel)
endmacro()
```

调用 kernel CMakeLists.txt，其实就是和 Findsel4.cmake 同文件夹的那个文件。这个 CMakeLists 内容很多且关键，定义了 kernel 编译，需要找寻其中的关键点

1. 确认工具位置，                               line 18~40
2. 根据 CPU Arch 做一些配置                     line 49~143
3. 增加一些 common compile flag                 line 145~257
4. 增加一些 CPU Arch relative compile flag      line 269~309
5. 增加 kernel include_directories              line 317~331
6. 增加 libsel4 include_directories，看起来 kernel 和 app 都依赖 libsel4   line 340~346
7. Config include generation，这部分存疑，需要确认 rel4 是否依赖这些生成的头文件 line 352~368
8. C 源文件生成                                 line 386~394
9. 各种头文件生成，需要进一步分析                  line 405~611
10. kernel 编译                                 line 623~679
11. install                                     line 693~end

### 2.4 用户空间编译

