abstract type VkType end

struct VkStruct <: VkType
	name::String
	fields::Vector{VkMember}
	attr::Attributes
end
VkStruct(name,attr) = VkStruct(name,VkMember[],attr)

struct VkUnion <: VkType
	name::String
	variants::Vector{VkMember}
	attr::Attributes
end
VkUnion(name,attr) = VkUnion(name,VkMember[],attr)


struct VkEnum <: VkType
	name::String
	fields::Vector{VkVariant}
	attr::Attributes
end
VkEnum(name,attr) = VkEnum(name,VkMember[],attr)

struct VkBitMask <: VkType
	name::String
	fields::Vector{VkVariant}
	attr::Attributes
end
VkBitMask(name,attr) = VkBitMask(name,VkMember[],attr)

struct VkHandle <: VkType
	name::String
	dispatchable::Bool
	attr::Attributes
end

VkHandle(attr) = VkHandle("",true,attr)

struct VkTypeDef <: VkType
	name::String
	typ::String
	requires::Union{Nothing,String}
	attr::Attributes
end

VkTypeDef(attr) = VkTypeDef("","",nothing,attr)


struct ApiConst <: VkType
	name::String
	value::String
	attr::Attributes
end



struct VkDefine <: VkType
	name::String
	attr::Attributes
end

VkDefine(attr) = VkDefine("",attr)

struct VkFuncPointer <: VkType
	name::String
	ret::VkElType
	params::Vector{VkElType}
	attr::Attributes
end

VkFuncPointer(attr) = VkFuncPointer("",VkElUnknown(),VkElType[],attr)


struct VkExternType <: VkType
	name::String
	requires::String
	attr::Attributes
end
