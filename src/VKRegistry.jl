module VkRegistry
using LibExpat

include("eltype.jl")
include("member.jl")
include("type.jl")
include("command.jl")
include("feat_ext.jl")

struct Registry
	tree::ETree
	types::Dict{AbstractString,VkType}
	consts::Vector{AbstractString}
	commands::Dict{AbstractString,VkCommand}
	feature::Dict{VkVersion,VkFeature}
	extensions::Dict{AbstractString,VkExtension}
end



include("generators.jl")

end # module
