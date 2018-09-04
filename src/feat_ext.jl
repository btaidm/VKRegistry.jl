
abstract type VkInterface end

struct CommandInterface <: VkInterface
	name::String
	profile::Union{Nothing,String}
	reqremAttr::Attributes
	attr::Attributes
end

struct TypeInterface <: VkInterface
	name::String
	profile::Union{Nothing,String}
	reqremAttr::Attributes
	attr::Attributes
end

struct ConstDefInterface <: VkInterface
	name::String
	value::String
	profile::Union{Nothing,String}
	reqremAttr::Attributes
	attr::Attributes
end

struct ApiConstInterface <: VkInterface
	name::String
	profile::Union{Nothing,String}
	reqremAttr::Attributes
	attr::Attributes
end

struct EnumInterface <: VkInterface
	variant::VkVariant
	extends::Union{Nothing,String}
	profile::Union{Nothing,String}
	reqremAttr::Attributes
	attr::Attributes
end

struct VkReqRem{R}
	profile::Union{Nothing,String}
	attr::Attributes
end


struct VkFeature
	name::String
	version::VkVersion
	require::Vector{VkInterface}
	remove::Vector{VkInterface}
	attr::Attributes
end

VkFeature(name,version,attr) = VkFeature(name,version,VkInterface[],VkInterface[],attr)


struct VkExtension
	name::String
	num::Int
	require::Vector{VkInterface}
	remove::Vector{VkInterface}
	attr::Attributes
end

VkExtension(name,num,attr) = VkExtension(name,num,VkInterface[],VkInterface[],attr)

pushCommand!(x::Union{VkFeature,VkExtension}, name::String, reqrem::VkReqRem{R}, attrs) where {R} = push!(getfield(x,R),CommandInterface(name,reqrem.profile,reqrem.attr,attrs))
pushType!(x::Union{VkFeature,VkExtension}, name::String, reqrem::VkReqRem{R}, attrs) where {R} = push!(getfield(x,R),TypeInterface(name,reqrem.profile,reqrem.attr,attrs))
pushConst!(x::Union{VkFeature,VkExtension}, name::String, value::String, reqrem::VkReqRem{R}, attrs) where {R} = push!(getfield(x,R),ConstDefInterface(name,value,reqrem.profile,reqrem.attr,attrs))
pushConst!(x::Union{VkFeature,VkExtension}, name::String, reqrem::VkReqRem{R}, attrs) where {R} = push!(getfield(x,R),ApiConstInterface(name,reqrem.profile,reqrem.attr,attrs))
pushEnum!(x::Union{VkFeature,VkExtension}, variant::VkVariant, extends::Union{Nothing,String}, reqrem::VkReqRem{R}, attrs) where {R} = push!(getfield(x,R),EnumInterface(variant,extends,reqrem.profile,reqrem.attr,attrs))
