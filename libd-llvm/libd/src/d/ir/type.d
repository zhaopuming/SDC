module d.ir.type;

import d.ir.symbol;

public import d.base.builtintype;
public import d.base.qualifier;

import d.base.type;

import d.context;

// Conflict with Interface in object.di
alias Interface = d.ir.symbol.Interface;

enum TypeKind : ubyte {
	Builtin,
	
	// Symbols
	Alias,
	Struct,
	Class,
	Interface,
	Union,
	Enum,
	
	// Context
	Context,
	
	// Type constructors
	Pointer,
	Slice,
	Array,
	
	// Sequence
	Sequence,
	
	// Complex types
	Function,
	
	// Template type
	Template,
}

struct Type {
private:
	mixin TypeMixin!(TypeKind, Payload);
	
	this(Desc d, inout Payload p = Payload.init) inout {
		desc = d;
		payload = p;
	}
	
	import util.fastcast;
	this(Desc d, inout Symbol s) inout {
		this(d, fastCast!(inout Payload)(s));
	}
	
	this(Desc d, inout Type* t) inout {
		this(d, fastCast!(inout Payload)(t));
	}
	
	Type getConstructedType(this T)(TypeKind k, TypeQualifier q) {
		return qualify(q).getConstructedMixin(k, q);
	}
	
	auto acceptImpl(T)(T t) {
		final switch(kind) with(TypeKind) {
			case Builtin :
				return t.visit(builtin);
			
			case Struct :
				return t.visit(dstruct);
			
			case Class :
				return t.visit(dclass);
			
			case Enum :
				return t.visit(denum);
			
			case Alias :
				// XXX: consider how to propagate the qualifier properly.
				return t.visit(dalias);
			
			case Interface :
				return t.visit(dinterface);
			
			case Union :
				return t.visit(dunion);
			
			case Context :
				return t.visit(context);
			
			case Pointer :
				return t.visitPointerOf(getElement());
			
			case Slice :
				return t.visitSliceOf(getElement());
			
			case Array :
				return t.visitArrayOf(size, getElement());
			
			case Sequence :
				return t.visit(sequence);
			
			case Function :
				return t.visit(asFunctionType());
			
			case Template :
				return t.visit(dtemplate);
		}
	}
	
public:
	auto accept(T)(ref T t) if(is(T == struct)) {
		return acceptImpl(&t);
	}
	
	auto accept(T)(T t) if(is(T == class)) {
		return acceptImpl(t);
	}
	
	Type qualify(TypeQualifier q) {
		auto nq = q.add(qualifier);
		if (nq == qualifier) {
			return Type(desc, payload);
		}
		
		switch(kind) with(TypeKind) {
			case Builtin, Struct, Class, Enum, Alias, Interface, Union, Context, Function :
				auto d = desc;
				d.qualifier = nq;
				return Type(d, payload);
			
			case Pointer :
				return getElement().qualify(nq).getPointer(nq);
			
			case Slice :
				return getElement().qualify(nq).getSlice(nq);
			
			case Array :
				return getElement().qualify(nq).getArray(size, nq);
			
			default :
				assert(0, "Not implemented");
		}
	}
	
	Type unqual() {
		auto d = desc;
		d.qualifier = TypeQualifier.Mutable;
		return Type(d, payload);
	}
	
	@property
	BuiltinType builtin() inout in {
		assert(kind == TypeKind.Builtin);
	} body {
		return cast(BuiltinType) desc.data;
	}
	
	bool isAggregate() const {
		return (kind >= TypeKind.Struct) && (kind <= TypeKind.Union);
	}
	
	@property
	auto aggregate() inout in {
		assert(isAggregate, "Not an aggregate type.");
	} body {
		return payload.agg;
	}
	
	@property
	auto dstruct() inout in {
		assert(kind == TypeKind.Struct);
	} body {
		return payload.dstruct;
	}
	
	@property
	auto dclass() inout in {
		assert(kind == TypeKind.Class);
	} body {
		return payload.dclass;
	}
	
	@property
	auto denum() inout in {
		assert(kind == TypeKind.Enum);
	} body {
		return payload.denum;
	}
	
	@property
	auto dalias() inout in {
		assert(kind == TypeKind.Alias);
	} body {
		return payload.dalias;
	}
	
	Type getCanonical() {
		if (kind != TypeKind.Alias) {
			return this;
		}
		
		return dalias.type.getCanonical().qualify(qualifier);
	}
	
	@property
	auto dinterface() inout in {
		assert(kind == TypeKind.Interface);
	} body {
		return payload.dinterface;
	}
	
	@property
	auto dunion() inout in {
		assert(kind == TypeKind.Union);
	} body {
		return payload.dunion;
	}
	
	@property
	auto context() inout in {
		assert(kind == TypeKind.Context);
	} body {
		return payload.context;
	}
	
	@property
	auto dtemplate() inout in {
		assert(kind == TypeKind.Template);
	} body {
		return payload.dtemplate;
	}
	
	Type getPointer(TypeQualifier q = TypeQualifier.Mutable) {
		return getConstructedType(TypeKind.Pointer, q);
	}
	
	Type getSlice(TypeQualifier q = TypeQualifier.Mutable) {
		return getConstructedType(TypeKind.Slice, q);
	}
	
	Type getArray(ulong size, TypeQualifier q = TypeQualifier.Mutable) {
		auto t = qualify(q);
		
		// XXX: Consider caching in context.
		auto n = new Type(t.desc, t.payload);
		return Type(Desc(TypeKind.Array, q, size), n);
	}
	
	bool hasElement() const {
		return (kind >= TypeKind.Pointer) && (kind <= TypeKind.Array);
	}
	
	auto getElement() inout in {
		assert(hasElement, "getElement called on a type with no element.");
	} body {
		if (kind == TypeKind.Array) {
			return *payload.next;
		}
		
		return getElementMixin();
	}
	
	@property
	uint size() const in {
		assert(kind == TypeKind.Array, "only array have size.");
	} body {
		return cast(uint) desc.data;
	}
	
	@property
	auto sequence() inout in {
		assert(kind == TypeKind.Sequence, "Not a sequence type.");
	} body {
		return payload.next[0 .. desc.data];
	}
	
	auto asFunctionType() inout in {
		assert(kind == TypeKind.Function, "Not a function.");
	} body {
		return inout(FunctionType)(desc, payload.params);
	}
	
	string toString(Context c, TypeQualifier q = TypeQualifier.Mutable) const {
		auto s = toUnqualString(c);
		if (q == qualifier) {
			return s;
		}
		
		final switch(qualifier) with(TypeQualifier) {
			case Mutable:
				return s;
			
			case Inout:
				return "inout(" ~ s ~ ")";
			
			case Const:
				return "const(" ~ s ~ ")";
			
			case Shared:
				return "shared(" ~ s ~ ")";
			
			case ConstShared:
				assert(0, "const shared isn't supported");
			
			case Immutable:
				return "immutable(" ~ s ~ ")";
		}
	}
	
	string toUnqualString(Context c) const {
		final switch(kind) with(TypeKind) {
			case Builtin :
				import d.base.builtintype : toString;
				return toString(builtin);
			
			case Struct :
				return dstruct.name.toString(c);
			
			case Class :
				return dclass.name.toString(c);
			
			case Enum :
				return denum.name.toString(c);
			
			case Alias :
				return dalias.name.toString(c);
			
			case Interface :
				return dinterface.name.toString(c);
			
			case Union :
				return dunion.name.toString(c);
			
			case Context :
				return "__ctx";
			
			case Pointer :
				return getElement().toString(c, qualifier) ~ "*";
			
			case Slice :
				return getElement().toString(c, qualifier) ~ "[]";
			
			case Array :
				import std.conv;
				return getElement().toString(c, qualifier) ~ "[" ~ to!string(size) ~ "]";
			
			case Sequence :
				import std.algorithm, std.range;
				// XXX: need to use this because of identifier hijacking in the import.
				return this.sequence.map!(e => e.toString(c, qualifier)).join(", ");
			
			case Function :
				auto f = asFunctionType();
				auto ret = f.returnType.toString(c);
				auto base = f.contexts.length ? " delegate(" : " function(";
				import std.algorithm, std.range;
				auto args = f.parameters.map!(p => p.toString(c)).join(", ");
				return ret ~ base ~ args ~ (f.isVariadic ? ", ...)" : ")");
			
			case Template :
				return dtemplate.name.toString(c);
		}
	}
	
static:
	Type get(BuiltinType bt, TypeQualifier q = TypeQualifier.Mutable) {
		Payload p;
		return Type(Desc(TypeKind.Builtin, q, bt), p);
	}
	
	Type get(Struct s, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Struct, q), s);
	}
	
	Type get(Class c, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Class, q), c);
	}
	
	Type get(Enum e, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Enum, q), e);
	}
	
	Type get(TypeAlias a, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Alias, q), a);
	}
	
	Type get(Interface i, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Interface, q), i);
	}
	
	Type get(Union u, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Union, q), u);
	}
	
	Type get(Type[] elements, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Sequence, q, elements.length), elements.ptr);
	}
	
	Type get(TypeTemplateParameter p, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Template, q), p);
	}
	
	Type getContextType(Function f, TypeQualifier q = TypeQualifier.Mutable) {
		return Type(Desc(TypeKind.Context, q), f);
	}
}

unittest {
	auto i = Type.get(BuiltinType.Int);
	auto pi = i.getPointer();
	assert(i == pi.getElement());
	
	auto ci = i.qualify(TypeQualifier.Const);
	auto cpi = pi.qualify(TypeQualifier.Const);
	assert(ci == cpi.getElement());
	assert(i != cpi.getElement());
}

unittest {
	auto i = Type.get(BuiltinType.Int);
	auto ai = i.getArray(42);
	assert(i == ai.getElement());
	assert(ai.size == 42);
}

unittest {
	auto i = Type.get(BuiltinType.Int);
	auto ci = Type.get(BuiltinType.Int, TypeQualifier.Const);
	auto cpi = i.getPointer(TypeQualifier.Const);
	assert(ci == cpi.getElement());
	
	auto csi = i.getSlice(TypeQualifier.Const);
	assert(ci == csi.getElement());
	
	auto cai = i.getArray(42, TypeQualifier.Const);
	assert(ci == cai.getElement());
}

unittest {
	import d.context, d.location, d.ir.symbol;
	auto c = new Class(Location.init, BuiltinName!"", []);
	auto tc = Type.get(c);
	assert(tc.isAggregate);
	assert(tc.aggregate is c);
	
	auto cc = Type.get(c, TypeQualifier.Const);
	auto csc = tc.getSlice(TypeQualifier.Const);
	assert(cc == csc.getElement());
}

alias ParamType = Type.ParamType;

string toString(const ParamType t, Context c) {
	string s;
	if (t.isRef && t.isFinal) {
		s = "final ref ";
	} else if (t.isRef) {
		s = "ref ";
	} else if (t.isFinal) {
		s = "final ";
	}
	
	return s ~ t.getType().toString(c);
}

inout(ParamType) getParamType(inout ParamType t, bool isRef, bool isFinal) {
	return t.getType().getParamType(isRef, isFinal);
}

unittest {
	auto pi = Type.get(BuiltinType.Int).getPointer(TypeQualifier.Const);
	auto p = pi.getParamType(true, false);
	
	assert(p.isRef == true);
	assert(p.isFinal == false);
	assert(p.qualifier == TypeQualifier.Const);
	
	auto pt = p.getType();
	assert(pt == pi);
}

struct FunctionType {
private:
	import std.bitmanip;
	mixin(bitfields!(
		Linkage, "lnk", 3,
		bool, "variadic", 1,
		bool, "dpure", 1,
		ulong, "ctxCount", 3,
		ulong, "paramCount", 50,
		uint, "", 6, // Pad for TypeKind and qualifier
	));
	
	ParamType* params;
	
	alias Desc = TypeDescriptor!TypeKind;
	
	this(Desc desc, inout ParamType* params) inout {
		// /!\ Black magic ahead.
		auto raw_desc = cast(ulong*) &desc;
		
		// Remove the TypeKind and qualifier
		*raw_desc = (*raw_desc >> 7);
		
		// This should point to an area of memory that have
		// the correct layout for the bitfield.
		auto f = cast(FunctionType*) raw_desc;
		
		// unqual trick required for bitfield
		auto unqual_this = cast(FunctionType*) &this;
		unqual_this.lnk = f.lnk;
		unqual_this.variadic = f.variadic;
		unqual_this.dpure = f.dpure;
		unqual_this.ctxCount = f.ctxCount;
		unqual_this.paramCount = f.paramCount;
		
		this.params = params;
	}

public:
	this(Linkage linkage, ParamType returnType, ParamType[] params, bool isVariadic) {
		lnk = linkage;
		variadic = isVariadic;
		dpure = false;
		ctxCount = 0;
		paramCount = params.length;
		this.params = (params ~ returnType).ptr;
	}
	
	this(Linkage linkage, ParamType returnType, ParamType ctxType, ParamType[] params, bool isVariadic) {
		lnk = linkage;
		variadic = isVariadic;
		dpure = false;
		ctxCount = 1;
		paramCount = params.length;
		this.params = (ctxType ~ params ~ returnType).ptr;
	}
	
	Type getType(TypeQualifier q = TypeQualifier.Mutable) {
		ulong d = *cast(ulong*) &this;
		auto p = Payload(cast(Type*) params);
		return Type(Desc(TypeKind.Function, q, d), p);
	}
	
	FunctionType getDelegate(ulong contextCount = 1) in {
		assert(contextCount <= paramCount + ctxCount);
	} body {
		auto t = this;
		t.ctxCount = contextCount;
		t.paramCount = paramCount + ctxCount - contextCount;
		return t;
	}
	
	@property
	Linkage linkage() const {
		return lnk;
	}
	
	@property
	bool isVariadic() const {
		return variadic;
	}
	
	@property
	bool isPure() const {
		return dpure;
	}
	
	@property
	auto returnType() inout {
		return params[ctxCount + paramCount];
	}
	
	@property
	auto contexts() inout {
		return params[0 .. ctxCount];
	}
	
	@property
	auto parameters() inout {
		return params[ctxCount .. ctxCount + paramCount];
	}
}

unittest {
	auto r = Type.get(BuiltinType.Void).getPointer().getParamType(false, false);
	auto c = Type.get(BuiltinType.Null).getSlice().getParamType(false, true);
	auto p = Type.get(BuiltinType.Float).getSlice(TypeQualifier.Immutable).getParamType(true, true);
	auto f = FunctionType(Linkage.Java, r, [c, p], true);
	
	assert(f.linkage == Linkage.Java);
	assert(f.isVariadic == true);
	assert(f.isPure == false);
	assert(f.returnType == r);
	assert(f.parameters.length == 2);
	assert(f.parameters[0] == c);
	assert(f.parameters[1] == p);
	
	auto ft = f.getType();
	assert(ft.asFunctionType() == f);
	
	auto d = f.getDelegate();
	assert(d.linkage == Linkage.Java);
	assert(d.isVariadic == true);
	assert(d.isPure == false);
	assert(d.returnType == r);
	assert(d.contexts.length == 1);
	assert(d.contexts[0] == c);
	assert(d.parameters.length == 1);
	assert(d.parameters[0] == p);
	
	auto dt = d.getType();
	assert(dt.asFunctionType() == d);
	assert(dt.asFunctionType() != f);
	
	auto d2 = d.getDelegate(2);
	assert(d2.contexts.length == 2);
	assert(d2.parameters.length == 0);
	assert(d2.getDelegate(0) == f);
}

private:

// XXX: we put it as a UFCS property to avoid forward reference.
@property
inout(ParamType)* params(inout Payload p) {
	import util.fastcast;
	return cast(inout ParamType*) p.next;
}

union Payload {
	Type* next;
	
	// Symbols
	TypeAlias dalias;
	Class dclass;
	Interface dinterface;
	Struct dstruct;
	Union dunion;
	Enum denum;
	
	// Context
	Function context;
	
	// For function and delegates.
	// ParamType* params;
	
	// For template instanciation.
	TypeTemplateParameter dtemplate;
	
	// For simple construction
	Symbol sym;
	Aggregate agg;
	ulong raw;
};

