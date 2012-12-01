module d.backend.string;

import d.backend.codegen;

import llvm.c.core;

import std.string;

final class StringGen {
	private CodeGenPass pass;
	alias pass this;
	
	this(CodeGenPass pass) {
		this.pass = pass;
	}
	
	// TODO: refactor that.
	private LLVMValueRef[string] stringLiterals;
	
	auto buildDString(string str) in {
		assert(str.length <= uint.max, "string length must be <= uint.max");
	} body {
		return stringLiterals.get(str, stringLiterals[str] = {
			auto charArray = LLVMConstString(str.ptr, cast(uint) str.length, true);
			
			auto globalVar = LLVMAddGlobal(pass.dmodule, LLVMTypeOf(charArray), ".str".toStringz());
			LLVMSetInitializer(globalVar, charArray);
			LLVMSetLinkage(globalVar, LLVMLinkage.Private);
			LLVMSetGlobalConstant(globalVar, true);
			
			auto length = LLVMConstInt(LLVMInt64Type(), str.length, false);
			
			/*
			// skip 0 termination.
			auto indices = [LLVMConstInt(LLVMInt64Type(), 0, true), LLVMConstInt(LLVMInt64Type(), 0, true)];
			auto ptr = LLVMBuildInBoundsGEP(pass.builder, globalVar, indices.ptr, 2, "");
			/*/
			// with 0 termination.
			auto ptr = LLVMBuildGlobalStringPtr(pass.builder, str.toStringz(), ".cstr");
			//*/
			
			return LLVMConstStruct([length, ptr].ptr, 2, false);
		}());
	}
}

