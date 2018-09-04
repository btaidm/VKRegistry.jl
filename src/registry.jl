using Rematch, EzXML

abstract type AbstractXmlElement end

struct TagElement{K <: AbstractString, V <: AbstractString} <:AbstractXmlElement
	name::AbstractString
	attr::Dict{K, V}
end

struct CharElement <: AbstractXmlElement
	chars::AbstractString
	tags::Tuple{AbstractString, Union{Nothing, AbstractString}}
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
	println("popping $el")
	if el isa CharElement
		pop_element_stack!(elements)
	end
	return nothing
end

function get_tags(elements::Vector{AbstractXmlElement})
	iters = Iterators.take(Iterators.filter(x->isa(x, TagElement), Iterators.reverse(elements)), 2)
	y = iterate(iters)
	tag1 = y[1].name
	y = iterate(iters, y[2])
	tag2 = (y === nothing ? nothing : y[1].name)
	return (tag1, tag2)
end

struct Registry
	# data::AbstractString
	types::Dict{AbstractString, VkType}
	consts::Vector{ApiConst}
	commands::Dict{AbstractString, VkCommand}
	features::Dict{VkVersion, VkFeature}
	extensions::Dict{AbstractString, VkExtension}
end


pushType!(reg::Registry, ::Nothing) = nothing
pushType!(reg::Registry, vkType::VkType) = (println("Adding Type: $(vkType)"); reg.types[vkType.name] = vkType)
pushType!(reg::Registry, vkconst::ApiConst) = push!(reg.consts, vkconst)


pushCommand!(reg::Registry, ::Nothing) = nothing
pushCommand!(reg::Registry, cmd::VkCommand) = reg.commands[cmd.name] = cmd

pushFeature!(reg::Registry, ::Nothing) = nothing
pushFeature!(reg::Registry, feat::VkFeature) = reg.features[feat.version] = feat

pushExtension!(reg::Registry, ::Nothing) = nothing
pushExtension!(reg::Registry, extn::VkExtension) = reg.extensions[extn.name] = extn



Registry(io::IO) = Registry(read(io, String))

function Registry(xml::AbstractString)

	buf = IOBuffer(xml)
	reader = EzXML.StreamReader(buf)


	vktypes = Dict{AbstractString, VkType}()
	vkconsts = AbstractString[]
	vkcommands = Dict{AbstractString, VkCommand}()
	vkfeature = Dict{VkVersion, VkFeature}()
	vkextensions = Dict{AbstractString, VkExtension}()

	reg = Registry(vktypes, vkconsts, vkcommands, vkfeature, vkextensions)


	type_buffer = Ref{Union{Nothing, VkType}}(nothing)
	command_buffer = Ref{Union{Nothing, VkCommand}}(nothing)
	feature_buffer = Ref{Union{Nothing, VkFeature}}(nothing)
	interface_reqrem = Ref{Union{Nothing, VkReqRem}}(nothing)
	extn_buffer = Ref{Union{Nothing, VkExtension}}(nothing)
	cur_blk = Ref{Union{Nothing, VkBlock}}(nothing)

	vk_elements = AbstractXmlElement[]

	poppedTo = Ref(1)

	for typ in reader
		@match typ begin
			x where x == EzXML.READER_ELEMENT => begin
				name = nodename(reader)
				println("----- Start $(name) -----")
				
				attributes = nodeattributes(reader)
				push!(vk_elements, TagElement(name, attributes))
			end
			x where x == EzXML.READER_END_ELEMENT => begin
				for el in vk_elements[(poppedTo[]):end]
					@show el
					# @show type_buffer command_buffer feature_buffer interface_reqrem extn_buffer cur_blk el
					@match el begin
						TagElement(tag_name, tag_attrs) => begin
							@match tag_name begin
								"enums" => begin
									name = tag_attrs["name"]
									println("==========")
									println("Start EnumBlk")
									pushType!(reg, type_buffer[])
									if name == "API Constants"
										type_buffer[] = VkEnum(name, tag_attrs)
									else
										@match tag_attrs["type"] begin
											 "enum" => (type_buffer[] = VkEnum(name, tag_attrs))
											 "bitmask" => (type_buffer[] = VkBitMask(name, tag_attrs))
											 t => error("Unexpected enum type $(t) $(name)")
										end
									end
									cur_blk[] = EnumBlk
								end
								"enum" where cur_blk[] == EnumBlk => begin
									name = tag_attrs["name"]
									println("EnumBlk: enum")
									@match type_buffer[] begin
										VkEnum(enum_name, variants, _) ||
										VkBitMask(enum_name, variants, _) => begin
											if enum_name == "API Constants"
												value = get(tag_attrs, "value") do; tag_attrs["alias"]; end
												pushType!(reg, ApiConst(name, value, tag_attrs))
											else
												push!(variants,
													if haskey(tag_attrs, "value")
														VkValue(name, parse(Int, tag_attrs["value"]), tag_attrs)
													elseif haskey(tag_attrs, "bitpos")
														VkBitpos(name, parse(Int, tag_attrs["bitpos"]), tag_attrs)
													elseif haskey(tag_attrs, "alias")
														VkAlias(name, tag_attrs["alias"], tag_attrs)
													else
														error("Could not find value or bitpos in enum")
													end
												)
											end
										end
										_ => nothing
									end
									
								end

								"types" => (cur_blk[] = TypeBlk; println("Start TypeBlk"))
								"type" where cur_blk[] == TypeBlk => begin
									# println("TypeBlk: type")
									if haskey(tag_attrs, "category")
										category = tag_attrs["category"]
										pushType!(reg, type_buffer[])
										println("==========")
										println("TypeBlk: $(category)")
										@match category begin
											"basetype" ||
											"bitmask" => (type_buffer[] = VkTypeDef(tag_attrs))
											"define" => begin
												if haskey(tag_attrs, "name")
													type_buffer[] = VkDefine(tag_attrs["name"], tag_attrs)
												else
													type_buffer[] = VkDefine(tag_attrs)
												end
											end
											"enum" => (type_buffer[] = nothing)
											"funcpointer" => (type_buffer[] = VkFuncPointer(tag_attrs))
											"group" => (type_buffer[] = nothing)
											"handle" => (type_buffer[] = VkHandle(tag_attrs))
											"include" => (type_buffer[] = nothing)
											"struct" => (type_buffer[] = VkStruct(tag_attrs["name"], tag_attrs))
											"union" => (type_buffer[] = VkUnion(tag_attrs["name"], tag_attrs))
										    _ => @warn("Unexpected Category: $category", maxlog=10)
										end
									elseif haskey(tag_attrs, "requires")
										println("TypeBlk: Extern")
										requires = tag_attrs["requires"]
										pushType!(reg, type_buffer[])
										println("==========")
										if haskey(tag_attrs, "name")
											type_buffer[] = VkExternType(tag_attrs["name"], requires, tag_attrs)
										else
											error("Expected external type name; found nothing")
										end
									end
								end
								"member" where cur_blk[] == TypeBlk => begin
									@match type_buffer[] begin
										VkStruct(name, members, _) || VkUnion(name, members, _) => begin
											println("TypeBlk: member for $(name)")
											push!(members, VkMember(haskey(tag_attrs, "optional") && tag_attrs["optional"] == "true", tag_attrs))
											type_buffer[] isa VkStruct && println(type_buffer[].fields)
											type_buffer[] isa VkUnion && println(type_buffer[].variants)
										end
										_ => error("Unexpected \"member\" tag found")
									end
								end 
								"member" => error("Member outside TypeBlk")

								"commands" => (cur_blk[] = CommandBlk; println("Start CommandBlk"))
								"command" where cur_blk[] == CommandBlk => begin
									println("CommandBlk: command")
									pushCommand!(reg, command_buffer[])
									command_buffer[] = VkCommand(tag_attrs)
								end
								"param" where cur_blk[] == CommandBlk => (println("CommandBlk: param"); push!(command_buffer[].params, VkParam(tag_attrs)))

								"feature" => begin 
									println("Start FeatureBlk")
									if haskey(tag_attrs, "name")
										if haskey(tag_attrs, "number")
											cur_blk[] = FeatureBlk
											pushFeature!(reg, feature_buffer[])
											feature_buffer[] = VkFeature(tag_attrs["name"], VkVersion(tag_attrs["number"]), tag_attrs)
										else
											error("Could not find feature number")
										end
									else
										error("Could not find feature name")
									end
								end
								"require" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: require")
									interface_reqrem[] = VkReqRem{:require}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"remove" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: remove")
									interface_reqrem[] = VkReqRem{:remove}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"command" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: command")
									pushCommand!(feature_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end
								"enum" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: enum")
									name = tag_attrs["name"]
									if haskey(tag_attrs, "extends")
										if haskey(tag_attrs, "offset")
											offset = parse(Int,tag_attrs["offset"])
											extn_num = parse(Int,tag_attrs["extnumber"])
											value = BASE_VALUE + (extn_num - 1) * RANGE_SIZE + offset
											if haskey(tag_attrs,"dir") && tag_attrs["dir"] == "-"
												value = -value
											end
											variant = VkValue(name,value,tag_attrs)
										elseif haskey(tag_attrs,"value")
											variant = VkValue(name,parse(Int,tag_attrs["value"]),tag_attrs)
										elseif haskey(tag_attrs,"bitpos")
											variant = VkBitpos(name,parse(UInt,tag_attrs["bitpos"]),tag_attrs)
										elseif haskey(tag_attrs, "alias")
											variant = VkAlias(name, tag_attrs["alias"], tag_attrs)
										else
											error("Invalid enum extension; missing \"offset\", \"alias\" or \"bitpos\"")
										end
										pushEnum!(feature_buffer[], variant, tag_attrs["extends"], interface_reqrem[], tag_attrs)
									elseif haskey(tag_attrs, "value")
										pushConst!(feature_buffer[], name, tag_attrs["value"], interface_reqrem[], tag_attrs)
									else
										pushConst!(feature_buffer[], name, interface_reqrem[], tag_attrs)
									end
								end
								"type" where cur_blk[] == FeatureBlk => begin
									println("FeatureBlk: type")
									pushType!(feature_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end

								"extensions" => (cur_blk[] = ExtensionBlk; println("Start ExtensionBlk"))
								"extension" where cur_blk[] == ExtensionBlk => begin
									if haskey(tag_attrs, "name")
										if haskey(tag_attrs, "number")
											println("ExtensionBlk: extension")
											pushExtension!(reg, extn_buffer[])
											extn_buffer[] = VkExtension(tag_attrs["name"], parse(Int, tag_attrs["number"]), tag_attrs)
										else
											error("Could not find extension number")
										end
									else
										error("Could not find extension name")
									end
								end
								"require" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: require")
									interface_reqrem[] = VkReqRem{:require}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"remove" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: remove")
									interface_reqrem[] = VkReqRem{:remove}(get(tag_attrs, "profile", nothing), tag_attrs)
								end
								"command" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: command")
									pushCommand!(extn_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end
								"type" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: type")
									pushType!(extn_buffer[], tag_attrs["name"], interface_reqrem[], tag_attrs)
								end
								"enum" where cur_blk[] == ExtensionBlk => begin
									println("ExtensionBlk: enum")
									name = tag_attrs["name"]
									if haskey(tag_attrs, "extends")
										if haskey(tag_attrs, "offset")
											offset = parse(Int,tag_attrs["offset"])
											extn_num = extn_buffer[].num
											value = BASE_VALUE + (extn_num - 1) * RANGE_SIZE + offset
											if haskey(tag_attrs,"dir") && tag_attrs["dir"] == "-"
												value = -value
											end
											variant = VkValue(name,value,tag_attrs)
										elseif haskey(tag_attrs,"value")
											variant = VkValue(name,parse(Int,tag_attrs["value"]),tag_attrs)
										elseif haskey(tag_attrs,"bitpos")
											variant = VkBitpos(name,parse(UInt,tag_attrs["bitpos"]),tag_attrs)
										elseif haskey(tag_attrs, "alias")
											variant = VkAlias(name, tag_attrs["alias"], tag_attrs)
										else
											error("Invalid enum extension; missing \"offset\", \"alias\" or \"bitpos\"")
										end
										pushEnum!(extn_buffer[], variant, tag_attrs["extends"], interface_reqrem[], tag_attrs)
									elseif haskey(tag_attrs, "value")
										pushConst!(extn_buffer[], name, tag_attrs["value"], interface_reqrem[], tag_attrs)
									else
										pushConst!(extn_buffer[], name, interface_reqrem[], tag_attrs)
									end
								end
								_ => nothing
							end
							# println(tag_name)
							# println(tag_attrs)
						end
						CharElement(char, (tag, tag1)) where
								(cur_blk[] == TypeBlk &&
								tag != "usage") => begin 
							@show cur_blk[], char, tag, tag1
						end
						CharElement(char, (tag, tag1)) where
								(cur_blk[] == CommandBlk &&
								tag != "usage") => begin 
							@show cur_blk[], char, tag, tag1
						end
						_ => nothing
					end
				end
				pop_element_stack!(vk_elements)
				poppedTo[] = length(vk_elements) + 1
				println(poppedTo[])
				println("----- End -----")
			end
			x where x == EzXML.READER_TEXT => begin
				tags = get_tags(vk_elements)
				chars = nodevalue(reader)
				push!(vk_elements, CharElement(chars, tags))
			end
			_ => nothing
		end
	end
	
	pushType!(reg, type_buffer[])
	pushCommand!(reg, command_buffer[])
	pushFeature!(reg, feature_buffer[])
	pushExtension!(reg, extn_buffer[])
	
	return reg

end

