classdef Attribute < handle
    properties
        name; %attribute key
        doc; %doc string
        required; %bool regarding whether or not this Attribute is required for class
        value; %Value
        readonly; %determines whether value can be changed or not
        dtype; %type of value
        dependent; %set externally.  If the attribute is actually dependent on an untyped dataset/group
        scalar; %if the value is scalar or an array
        dimnames;
        shape;
    end
    
    methods
        function obj = Attribute(source)
            %defaults
            obj.name = '';
            obj.doc = '';
            obj.required = true;
            obj.value = [];
            obj.readonly = false;
            obj.dtype = '';
            obj.dependent = '';
            obj.scalar = true;
            obj.shape = {};
            obj.dimnames = {};
            
            if nargin < 1
                return;
            end
            
            obj.name = source('name');
            obj.doc = source('doc');
            requiredKey = 'required';
            if isKey(source, requiredKey)
                requiredFlag = source(requiredKey);
                obj.required = ~strcmp(requiredFlag, 'false');
            end
            
            valueKey = 'value';
            defaultKey = 'default_value';
            if isKey(source, defaultKey)
                obj.value = source(defaultKey);
                obj.readonly = false;
            elseif isKey(source, valueKey)
                obj.value = source(valueKey);
                obj.readonly = true;
            else
                obj.value = [];
                obj.readonly = false;
            end
            
            boundsKey = 'dims';
            shapeKey = 'shape';
            if isKey(source, shapeKey) && isKey(source, boundsKey)
                shape = source(shapeKey);
                obj.dimnames = source(boundsKey);
                obj.shape = file.formatShape(shape);
                if ischar(obj.shape)
                    obj.scalar = ~strcmp(obj.shape, 'Inf');
                elseif iscellstr(obj.shape)
                    obj.scalar = ~any(strcmp(obj.shape, 'Inf'));
                end
            else
                obj.shape = '1';
                obj.dimnames = {obj.name};
            end
            
            obj.dtype = file.mapType(source('dtype'));
        end
    end
end
