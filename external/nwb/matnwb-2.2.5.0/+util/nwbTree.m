function nwbTree(nwbfile)
    
f = uifigure('Name', 'NWB Tree');
tree = uitree(f,'Position',[20, 20 f.Position(3) - 20, f.Position(4) - 20]);
traverse_node(nwbfile, tree)

end


function out = traverse_node(node, tree_node)

if any(strcmp(superclasses(node), 'types.untyped.GroupClass')) || isa(node, 'types.untyped.DataStub')
    pp = properties(node);
    for p = pp'
        if ~isempty(node.(p{1}))
            new_node = node.(p{1});
            if any(strcmp(superclasses(new_node), 'types.untyped.GroupClass'))
                new_tree_node = uitreenode(tree_node, 'Text', p{1});
                traverse_node(new_node, new_tree_node)
            elseif isa(new_node, 'types.untyped.Set')
                if new_node.Count
                    new_tree_node = uitreenode(tree_node, 'Text', p{1});
                    traverse_node(new_node, new_tree_node)
                end
            elseif isa(new_node, 'types.untyped.DataStub')
                new_tree_node = uitreenode(tree_node, 'Text', p{1});
                traverse_node(new_node, new_tree_node)
            elseif isa(new_node, 'char')
                uitreenode(tree_node, 'Text', [p{1} ': ' new_node]);
            elseif isnumeric(new_node)
                if numel(new_node)  == 1
                    uitreenode(tree_node, 'Text', [p{1} ': ' num2str(new_node)]);
                else
                    data_node = uitreenode(tree_node, 'Text', p{1});
                    uitreenode(data_node, 'Text', ['shape: [' num2str(size(new_node)) ']'])
                    uitreenode(data_node, 'Text', ['class: ' class(new_node)])
                end 
            else
                uitreenode(tree_node, 'Text', p{1});
            end
        end
    end
elseif isa(node, 'types.untyped.Set')
    for key = node.keys()
        new_tree_node = uitreenode(tree_node, 'Text', key{1});
        traverse_node(node.get(key{1}), new_tree_node)
    end
end


function [ bytes ] = getMemSize( variable, sizelimit, name, indent )
    if nargin < 2
        sizelimit = -1;
    end
    if nargin < 3
        name = 'variable';       
    end
    if nargin < 4
        indent = '';
    end
    
    strsize = 30;
    
    props = properties(variable); 
    if size(props, 1) < 1
        
        bytes = whos(varname(variable)); 
        bytes = bytes.bytes;
        
        if bytes > sizelimit
            if bytes < 1024
                fprintf('%s%s: %i\n', indent, pad(name, strsize - length(indent)), bytes);
            elseif bytes < 2^20
                fprintf('%s%s: %i Kb\n', indent, pad(name, strsize - length(indent)), round(bytes / 2^10));
            elseif bytes < 2^30
                fprintf('%s%s: %i Mb\n', indent, pad(name, strsize - length(indent)), round(bytes / 2^20));
            else
                fprintf('%s%s: %i Gb [!]\n', indent, pad(name, strsize - length(indent)), round(bytes / 2^30));
            end
        end
    else
        
        fprintf('\n%s[%s] \n\n', indent, name);
        bytes = 0;
        for ii=1:length(props)
            currentProperty = getfield(variable, char(props(ii)));
            pp = props(ii);
            bytes = bytes + getMemSize(currentProperty, sizelimit, pp{1}, [indent, '  ']);
        end                
                
        if length(indent) == 0
            fprintf('\n');
            name = 'TOTAL';
            if bytes < 1024
                fprintf('%s%s: %i\n', indent, pad(name, strsize - length(indent)), bytes);
            elseif bytes < 2^20
                fprintf('%s%s: %i Kb\n', indent, pad(name, strsize - length(indent)), round(bytes / 2^10));
            elseif bytes < 2^30
                fprintf('%s%s: %i Mb\n', indent, pad(name, strsize - length(indent)), round(bytes / 2^20));
            else
                fprintf('%s%s: %i Gb [!]\n', indent, pad(name, strsize - length(indent)), round(bytes / 2^30));
            end
        end
    
    end   
        
end


end