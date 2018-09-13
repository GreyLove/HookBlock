////
////  HookBlock.m
////  block
////
////  Created by gl on 2018/9/13.
////  Copyright © 2018年 gl. All rights reserved.
////
//
//#import "HookBlock.h"
//#import "ffi.h"
//
//typedef id (*_IMP)(id, SEL, ...);
//typedef void (*_VIMP)(id, SEL, ...);
//
//
//struct __block_impl {
//    void *isa;
//    int Flags;
//    int Reserved;
//    void *FuncPtr;
//};
//
////位运算，得到方法签名 默认都是有签名的
//enum {
//    BLOCK_HAS_COPY_DISPOSE =  (1 << 25), //是否有copy函数
//    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
//    BLOCK_IS_GLOBAL =         (1 << 28),
//    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
//    BLOCK_HAS_SIGNATURE =     (1 << 30), //是否有block方法签名
//};
//
//struct __main_block_desc_0 {
//    size_t reserved;
//    size_t Block_size;
//    void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
//    void (*dispose_helper)(void *src);             // IFF (1<<25)
//    const char *signature;
//};
//
//struct __main_block_impl_0 {
//    struct __block_impl impl;
//    struct __main_block_desc_0* Desc;
//};
//
//@interface HookBlock()
//
//{
//    void *_replacement_invoke;
//    void *_origin_invoke;
//    ffi_cif _cif;
//    ffi_closure *_closure;
//}
//
//@end
//
//
//@implementation HookBlock
//
//
////是否有签名
//static BOOL block_has_signature(int flags){
//    return flags & BLOCK_HAS_SIGNATURE;
//}
////是否有copy dispose 函数
//static BOOL block_has_copy_dispose(int flags){
//    return flags & BLOCK_HAS_COPY_DISPOSE;
//}
//
//static NSMethodSignature *blockSignature(id block){
//    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
//    if (block_has_signature(imp->impl.Flags)) {
//        return nil;
//    }
//    NSMethodSignature *sign;
//    if (block_has_copy_dispose(imp->impl.Flags)) { //如果有copy dispose 函数
//        sign = [NSMethodSignature signatureWithObjCTypes:imp->Desc->signature];
//    }else{
//        sign = [NSMethodSignature signatureWithObjCTypes:(const char*)imp->Desc->copy_helper];//copy_helper 函数地址就是signature 都是指针 8字节
//    }
//    return sign;
//}
//
//static NSUInteger blockArgsCount(id block){
//    NSMethodSignature *sign = blockSignature(block);
//    return sign.numberOfArguments;
//}
//
//static void *ffi_args_encode(const char * s){
//    NSLog(@"%c",s[0]);
//    switch (s[0]) {
//        case 'v':
//            return &ffi_type_void;
//        case 'c':
//            return &ffi_type_schar;
//        case 'C':
//            return &ffi_type_uchar;
//        case 's':
//            return &ffi_type_sshort;
//        case 'S':
//            return &ffi_type_ushort;
//        case 'i':
//            return &ffi_type_sint;
//        case 'I':
//            return &ffi_type_uint;
//        case 'l':
//            return &ffi_type_slong;
//        case 'L':
//            return &ffi_type_ulong;
//        case 'q':
//            return &ffi_type_sint64;
//        case 'Q':
//            return &ffi_type_uint64;
//        case 'f':
//            return &ffi_type_longdouble;
//        case 'd':
//            return &ffi_type_longdouble;
//        case 'F':
//#if CGFLOAT_IS_DOUBLE
//            return &ffi_type_longdouble;
//#else
//            return &ffi_type_longdouble;
//#endif
//        case 'B':
//            return &ffi_type_uint8;
//        case '^':
//            return &ffi_type_pointer;
//        case '@':
//            return &ffi_type_pointer;
//        case '#':
//            return &ffi_type_pointer;
//    }
//    return NULL;
//}
//
//
//static ffi_type ** ffi_args_types(id block){
//    NSUInteger count = blockArgsCount(block);
//    ffi_type **types;  // 参数类型
//    types = malloc(sizeof(ffi_type *) * count) ;
//    NSMethodSignature *sign = blockSignature(block); //通过方法签名解析出 返回值和参数类型，然后生成数组
//    for (int i = 0; i < count; i++) {
//        const char * s = [sign getArgumentTypeAtIndex:i];
//        ffi_type *type = ffi_args_encode(s);
//        types[i] = type;
//    }
//    return types;
//}
//
//static ffi_type * ffi_return_type(id block){
//    NSMethodSignature *sign = blockSignature(block); //通过方法签名解析出 返回值和参数类型，然后生成数组
//    const char * s =[sign methodReturnType];
//    ffi_type *type = ffi_args_encode(s);
//    return type;
//}
//
///*
// ffi_type **types;  // 参数类型
// ffi_prep_cif : 生成模板
// ffi_call:动态调用
// */
//
//
//static void ffi_function(ffi_cif *cif, void *ret, void **args, void *userdata) {
//    // args为所有参数的内存地址
//    id blockObj = (__bridge id)(userdata);
//
//    int i = *((int *)args[1]);
//    NSString *str = (__bridge NSString *)(*((void **)args[2]));
//    NSLog(@"%d,%@", i, str);
//    if (_origin_invoke) {
//        ffi_call(cif, _origin_invoke, ret, args);
//    }
//}
//
//- (void)HookBlockToPrintArguments:(id)block{
//    struct __main_block_impl_0 *imp = (__bridge struct __main_block_impl_0*)block;
//    
//    ffi_type **types = ffi_args_types(block);
//    ffi_type *returnType = ffi_return_type(block);
//    
//    
//    // 生成模板
//    ffi_status status0 = ffi_prep_cif(&_cif, FFI_DEFAULT_ABI, (unsigned int)blockArgsCount(block), returnType, types);
//    if (status0 != FFI_OK) {
//        return;
//    }
//    
//    //生成一个闭包
//    _closure = ffi_closure_alloc(sizeof(ffi_closure), &_replacement_invoke);
//    ffi_status status = ffi_prep_closure_loc(_closure, &_cif, ffi_function, (__bridge void *)block, _replacement_invoke);
//    if (status != FFI_OK) {
//        return;
//    }
//    
//    _origin_invoke = imp->impl.FuncPtr;
//    imp->impl.FuncPtr = _replacement_invoke;
//
//}
//
//- (void)dealloc
//{
//    
//}
//
//+ (void)hookBlock:(id)block{
//    HookBlock *hookBlock = [[HookBlock alloc] init];
//    [hookBlock HookBlockToPrintArguments:block];
//}
//
//@end
