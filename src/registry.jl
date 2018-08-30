using Rematch, EzXML

abstract type AbstractXmlElement end

struct TagElement{K <: AbstractString,V <: AbstractString} <:AbstractXmlElement
	name::AbstractString
	attr::Dict{K,V}
end

struct CharElement <: AbstractXmlElement
	chars::AbstractString
	tags::Tuple{AbstractString,Union{Nothing,AbstractString}}
end


@enum(VkBlock,
	TypeBlk,
	EnumBlk,
	CommandBlk,
	ExtensionBlk,
	FeatureBlk)

const BASE_VALUE = 1000000000
const RANGE_SIZE = 1000

function pop_element_stack!(elements::Vector{AbstractXmlElement})
	el = pop!(elements)
	if el isa CharElement
		pop_element_stack!(elements)
	end
	return nothing
end

function get_tags(elements::Vector{AbstractXmlElement})
	iters = Iterators.take(Iterators.filter(x->isa(x,TagElement),Iterators.reverse(elements)),2)
	y = iterate(iters)
	tag1 = y[1].name
	y = iterate(iters,y[2])
	tag2 = (y === nothing ? nothing : y[1].name)
	return (tag1,tag2)
end

struct Registry
	data::AbstractString
	types::Dict{AbstractString,VkType}
	consts::Vector{AbstractString}
	commands::Dict{AbstractString,VkCommand}
	feature::Dict{VkVersion,VkFeature}
	extensions::Dict{AbstractString,VkExtension}
end


Registry(io::IO) = Registry(read(io,String))

function Registry(xml::AbstractString)
	buf = IOBuffer(xml)
	reader = EzXML.StreamReader(buf)


	vktypes = Dict{AbstractString,VkType}()
	vkconsts = AbstractString[]
	vkcommands = Dict{AbstractString,VkCommand}()
	vkfeature = Dict{VkVersion,VkFeature}()
	vkextensions = Dict{AbstractString,VkExtension}()

	type_buffer = Ref{Union{Nothing,VkType}}(nothing)
	command_buffer = Ref{Union{Nothing,VkCommand}}(nothing)
	feature_buffer = Ref{Union{Nothing,VkFeature}}(nothing)
	interface_reqrem = Ref{Union{Nothing,VkReqRem}}(nothing)
	extn_buffer = Ref{Union{Nothing,VkExtension}}(nothing)
	cur_blk = Ref{Union{Nothing,VkBlock}}(nothing)

	vk_elements = AbstractXmlElement[]

	poppedTo = Ref(1)

	for typ in reader
		@match typ begin
			x where x == EzXML.READER_ELEMENT => begin
				name = nodename(reader)
				attributes = nodeattributes(reader)
				push!(vk_elements,TagElement(name,attributes))
			end
			x where x == EzXML.READER_END_ELEMENT => begin
				for el in vk_elements[(poppedTo[]):end]
					@match el begin
						TagElement(tag_name, tag_attrs) => begin
							@match tag_name begin
								"enums" => begin
									name = tag_attrs["name"]

									println("Start EnumBlk")
									cur_blk[] = EnumBlk
								end
								"enum" where cur_blk[] == EnumBlk => println("EnumBlk: enum")

								"types" => (cur_blk[] = TypeBlk; println("Start TypeBlk"))
								"type" where cur_blk[] == TypeBlk => println("TypeBlk: type")
								"member" where cur_blk[] == TypeBlk => println("TypeBlk: member")
								"member" => println("Member outside TypeBlk")

								"commands" => (cur_blk[] = CommandBlk; println("Start CommandBlk"))
								"command" where cur_blk[] == CommandBlk => println("CommandBlk: command")
								"param" where cur_blk[] == CommandBlk => println("CommandBlk: param")

								"feature" => (cur_blk[] = FeatureBlk; println("Start FeatureBlk"))
								"require" where cur_blk[] == FeatureBlk => println("FeatureBlk: require")
								"remove" where cur_blk[] == FeatureBlk => println("FeatureBlk: remove")
								"command" where cur_blk[] == FeatureBlk => println("FeatureBlk: command")
								"enum" where cur_blk[] == FeatureBlk => println("FeatureBlk: enum")
								"type" where cur_blk[] == FeatureBlk => println("FeatureBlk: type")

								"extensions" => (cur_blk[] = ExtensionBlk; println("Start ExtensionBlk"))
								"extension" where cur_blk[] == ExtensionBlk => println("ExtensionBlk: extension")
								"command" where cur_blk[] == ExtensionBlk => println("ExtensionBlk: command")
								"type" where cur_blk[] == ExtensionBlk => println("ExtensionBlk: type")
								"enum" where cur_blk[] == ExtensionBlk => println("ExtensionBlk: enum")
								_ => nothing
							end
							# println(tag_name)
							# println(tag_attrs)
						end
						CharElement(char, (tag, tag1)) where
								(cur_blk[] == TypeBlk &&
								tag != "usage") => begin 
							@show cur_blk[],char,tag,tag1
						end
						CharElement(char, (tag, tag1)) where
								(cur_blk[] == CommandBlk &&
								tag != "usage") => begin 
							@show cur_blk[],char,tag,tag1
						end
						_ => nothing
					end
				end
				pop_element_stack!(vk_elements)
				poppedTo[] = length(vk_elements) != 0 ? length(vk_elements) : 1
			end
			x where x == EzXML.READER_TEXT => begin
				tags = get_tags(vk_elements)
				chars = nodevalue(reader)
				push!(vk_elements,CharElement(chars,tags))
			end
			_ => nothing
		end
	end


	Registry(xml,vktypes,vkconsts,vkcommands,vkfeature,vkextensions)
end

