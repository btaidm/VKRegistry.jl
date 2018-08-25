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

Registry(tree::AbstractString) = Registry(xp_parse(tree))

Registry(io::IO) = Registry(read(io,String))

function Registry(tree::ETree)
	vktypes = Dict{AbstractString,VkType}()
	vkconsts = AbstractString[]
	vkcommands = Dict{AbstractString,VkCommand}()
	vkfeature = Dict{VkVersion,VkFeature}()
	vkextensions = Dict{AbstractString,VkExtension}()
	Registry(tree,vktypes,vkconsts,vkcommands,vkfeature,vkextensions)
end


include("generators.jl")

end # module
