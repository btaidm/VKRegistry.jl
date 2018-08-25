abstract type VkType end

struct VkStruct <: VkType
	name::AbstractString
	fields::Vector{VkMember}
	attr::Dict{AbstractString,Any}
end

struct VkUnion <: VkType
	name::AbstractString
	variants::Vector{VkMember}
	attr::Dict{AbstractString,Any}
end

struct VkEnum <: VkType
	name::AbstractString
	fields::Vector{VkVariant}
	attr::Dict{AbstractString,Any}
end

struct VkBitMask <: VkType
	name::AbstractString
	fields::Vector{VkVariant}
	attr::Dict{AbstractString,Any}
end

struct VkHandle <: VkType
	name::AbstractString
	dispatchable::Bool
	attr::Dict{AbstractString,Any}
end

struct VkTypeDef <: VkType
	name::AbstractString
	typ::AbstractString
	requires::Union{Nothing,AbstractString}
	attr::Dict{AbstractString,Any}
end

struct ApiConst <: VkType
	name::AbstractString
	value::AbstractString
	attr::Dict{AbstractString,Any}
end

struct VkDefine <: VkType
	name::AbstractString
	attr::Dict{AbstractString,Any}
end

struct VkFuncPointer <: VkType
	name::AbstractString
	ret::VkElType
	params::Vector{VkElType}
	attr::Dict{AbstractString,Any}
end

struct VkExternType <: VkType
	name::AbstractString
	requires::AbstractString
	attr::Dict{AbstractString,Any}
end
