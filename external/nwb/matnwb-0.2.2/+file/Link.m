classdef Link < handle
    properties(SetAccess=private)
        doc;
        name;
        required;
        type;
    end
    
    methods
        function obj = Link(source)
            obj.doc = [];
            obj.name = [];
            obj.required = true;
            obj.type = [];
            if nargin < 1
                return;
            end
            
            obj.doc = source('doc');
            obj.name = source('name');
            obj.type = source('target_type');
            
            quantityKey = 'quantity';
            if isKey(source, quantityKey)
                quantity = source(quantityKey);
                obj.required = strcmp(quantity, '+');
            end
        end
    end
end