function checkDependent(parent, children, unconstructed)
    if ~any(strcmp(parent, unconstructed))
        for i=1:length(children)
            child = children{i};
            if any(strcmp(child, unconstructed))
                error('Dependent type `%s` is required for parent property `%s`', child, parent);
            end
        end
    end
end