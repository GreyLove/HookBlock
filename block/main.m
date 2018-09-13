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

//由于block会捕获变量，而且copy_helper，dispose_helper不一定会有，所以struct __main_block_desc_0 本身大小是动态的，所有ReservedFuncPtr 函数指针放在此结构体中。
//copy_helper，dispose_helper 可能不会出现
struct __main_block_desc_0 {
    size_t reserved;
    size_t Block_size;
    void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
    void (*dispose_helper)(void *src);             // IFF (1<<25)
    const char *signature;
    void *ReservedFuncPtr;
};

struct __main_block_impl_0 {
    struct __block_impl impl;
    struct __main_block_desc_0* Desc;
};

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

void *ffi_args_encode(const char * s){
    switch (s[0]) {
        case 'v':
            return &ffi_type_void;
        case 'c':
            return &ffi_type_schar;
        case 'C':
            return &ffi_type_uchar;
        case 's':
            return &ffi_type_sshort;
        case 'S':
            return &ffi_type_ushort;
        case 'i':
            return &ffi_type_sint;
        case 'I':
            return &ffi_type_uint;
        case 'l':
            return &ffi_type_slong;
        case 'L':
            return &ffi_type_ulong;
        case 'q':
            return &ffi_type_sint64;
        case 'Q':
            return &ffi_type_uint64;
        case 'f':
            return &ffi_type_longdouble;
        case 'd':
            return &ffi_type_longdouble;
        case 'F':
#if CGFLOAT_IS_DOUBLE
            return &ffi_type_longdouble;
#else
            return &ffi_type_longdouble;
#endif
        case 'B':
            return &ffi_type_uint8;
        case '^':
            return &ffi_type_pointer;
        case '@':
            return &ffi_type_pointer;
        case '#':
            return &ffi_type_pointer;
    }
    return NULL;
}


ffi_type ** ffi_args_types(id block){
    NSUInteger count = blockArgsCount(block);
    ffi_type **types;  // 参数类型
    types = malloc(sizeof(ffi_type *) * count) ;
    NSMethodSignature *sign = blockSignature(block); //通过方法签名解析出 返回值和参数类型，然后生成数组
    for (int i = 0; i < count; i++) {
        const char * s = [sign getArgumentTypeAtIndex:i];
        ffi_type *type = ffi_args_encode(s);
        types[i] = type;
    }
    return types;
}

ffi_type * ffi_return_type(id block){
    NSMethodSignature *sign = blockSignature(block); //通过方法签名解析出 返回值和参数类型，然后生成数组
    const char * s =[sign methodReturnType];
    ffi_type *type = ffi_args_encode(s);
    return type;
}



void ffi_function(ffi_cif *cif, void *ret, void **args, void *userdata) {
    // args为所有参数的内存地址
    //默认会传block本身
    struct __main_block_impl_0 *imp = (*((void **)args[0]));
    int i = *(int *)((void **)args[1]);
    NSString *str = (__bridge NSString *)(*((void **)args[2]));
    NSLog(@"%@--%d--%@",imp,i,str);
    ffi_call(cif, imp->Desc->ReservedFuncPtr, ret, args);

}

//2
void HookBlockToPrintArguments(id block){
    
    /*
     ffi_type **types;  // 参数类型
     ffi_prep_cif : 生成模板
     ffi_call:动态调用
     */
    
    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
    
    ffi_type **types = ffi_args_types(block);//malloc 出来的对象
    ffi_type *returnType = ffi_return_type(block);
    
    ffi_cif cif;
    // 生成模板
    ffi_status status0 = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, (unsigned int)blockArgsCount(block), returnType, types);
    if (status0 != FFI_OK) {
        return;
    }
    
    //生成一个闭包
    ffi_closure *closure = ffi_closure_alloc(sizeof(ffi_closure), &imp->Desc->ReservedFuncPtr);//malloc 出来的对象
    ffi_status status = ffi_prep_closure_loc(closure, &cif, ffi_function, NULL, imp->Desc->ReservedFuncPtr);
    if (status != FFI_OK) {
        return;
    }
    
    void *tmp  = imp->impl.FuncPtr;
    imp->impl.FuncPtr = imp->Desc->ReservedFuncPtr;
    imp->Desc->ReservedFuncPtr = tmp;
}


//1
void test(id self){
    NSLog(@"hello world");
}

void HookBlockToPrintHelloWorld(id block){
    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
    imp->impl.FuncPtr = (_IMP*)test;
}

int main(int argc, const char * argv[]) {
    
    NSLog(@"1答案：--------------");
    dispatch_block_t block = ^{
        NSLog(@"hook--block");
    };
    HookBlockToPrintHelloWorld(block);
    block();
    /*--------------------------------------------------------*/
    NSLog(@"2答案：--------------");
    int a1 = 22;
    void(^block1)(int a,NSString *b,NSString * c,float d) = ^(int a,NSString *b,NSString * c,float d){
        NSLog(@"hook--block--%d",a1);
    };
    HookBlockToPrintArguments(block1);
    block1(10,@"10",@"10.00",3.);
    
    
    return 0;
}
