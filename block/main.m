//
//  main.m
//  block
//
//  Created by gl on 2018/9/11.
//  Copyright © 2018年 gl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ffi.h"

typedef id (*_IMP)(id, SEL, ...);
typedef void (*_VIMP)(id, SEL, ...);


struct __block_impl {
    void *isa;
    int Flags;
    int Reserved;
    void *FuncPtr;
};

//位运算，得到方法签名 默认都是有签名的
enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), //是否有copy函数
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30), //是否有block方法签名
};

struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
    void (*dispose_helper)(void *src);             // IFF (1<<25)
    const char *signature;
};



struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
};

//1
//void test(id self){
//    NSLog(@"hook--block");
//}
//
//void HookBlockToPrintHelloWorld(id block){
//    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
//    imp->impl.FuncPtr = (_IMP*)test;
//}





//是否有签名
BOOL block_has_signature(int flags){
    return flags & BLOCK_HAS_SIGNATURE;
}
//是否有copy dispose 函数
BOOL block_has_copy_dispose(int flags){
    return flags & BLOCK_HAS_COPY_DISPOSE;
}

NSMethodSignature *blockSignature(id block){
    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
    if (block_has_signature(imp->impl.Flags)) {
        return nil;
    }
    NSMethodSignature *sign;
    if (imp->impl.Flags & BLOCK_HAS_COPY_DISPOSE) { //如果有copy dispose 函数
         sign = [NSMethodSignature signatureWithObjCTypes:imp->Desc->signature];
    }else{
        sign = [NSMethodSignature signatureWithObjCTypes:(const char*)imp->Desc->copy_helper];//copy_helper 函数地址就是signature 都是指针 8字节
    }
    return sign;
}

NSUInteger blockArgsCount(id block){
    NSMethodSignature *sign = blockSignature(block);
    return sign.numberOfArguments;
}
/*
 ffi_type **types;  // 参数类型
 ffi_prep_cif : 生成模板
 ffi_call:动态调用
 */

void *g_replacement_invoke;
void *g_origin_invoke;

void ffi_function(ffi_cif *cif, void *ret, void **args, void *userdata) {
    // args为所有参数的内存地址
    int i = *((int *)args[1]);
    NSString *str = (__bridge NSString *)(*((void **)args[2]));
    NSLog(@"%d,%@", i, str);
    if (g_origin_invoke) {
        ffi_call(cif, g_origin_invoke, ret, args);
    }
}

void HookBlockToPrintArguments(id block){
    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
//    NSMethodSignature *sign = blockSignature(block); //通过方法签名解析出 返回值和参数类型，然后生成数组
    NSUInteger count = blockArgsCount(block);
    
    ffi_type **types;  // 参数类型
    types = malloc(sizeof(ffi_type *) * count) ;
    types[0] = &ffi_type_pointer;
    types[1] = &ffi_type_sint;
    types[2] = &ffi_type_pointer;
    ffi_type *returnType = &ffi_type_void;
    ffi_cif cif;
    // 生成模板
    ffi_status status0 = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)count, returnType, types);
    if (status0 == FFI_OK) {
        //生成一个闭包
        ffi_closure *closure = ffi_closure_alloc(sizeof(ffi_closure), &g_replacement_invoke);
        ffi_status status = ffi_prep_closure_loc(closure, &cif, ffi_function, NULL, g_replacement_invoke);
        if (status == FFI_OK) {
        }
    }
    
    g_origin_invoke = imp->impl.FuncPtr;
    imp->impl.FuncPtr = g_replacement_invoke;
}


int main(int argc, const char * argv[]) {
    
    //2
    void(^block1)(int a,NSString *b) = ^(int a,NSString *b){
        NSLog(@"hook--block");
    };
    
    HookBlockToPrintArguments(block1);
    block1(10,@"10");
    
    return 0;
}
