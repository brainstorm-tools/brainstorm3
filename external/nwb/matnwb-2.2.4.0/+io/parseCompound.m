function data = parseCompound(did, data)
%did is the dataset_id for the containing dataset
%data should be a scalar struct with fields as columns
if isempty(data)
    return;
end
tid = H5D.get_type(did);
ncol = H5T.get_nmembers(tid);
subtids = cell(1, ncol);
ref_i = false(1, ncol);
char_i = false(1, ncol);
for i = 1:ncol
    subtid = H5T.get_member_type(tid, i-1);
    subtids{i} = subtid;
    switch H5T.get_member_class(tid, i-1)
        case H5ML.get_constant_value('H5T_REFERENCE')
            ref_i(i) = true;
        case H5ML.get_constant_value('H5T_STRING')
            %if not variable len (which would make it a cell array)
            %then mark for transpose
            char_i(i) = ~H5T.is_variable_str(subtid);
        otherwise
            %do nothing
    end
end
propnames = fieldnames(data);
if any(ref_i)
    %resolve references by column
    reftids = subtids(ref_i);
    refPropNames = propnames(ref_i);
    for j=1:length(refPropNames)
        rpname = refPropNames{j};
        refdata = data.(rpname);
        reflist = cell(size(refdata, 2), 1);
        for k=1:size(refdata, 2)
            r = refdata(:,k);
            reflist{k} = io.parseReference(did, reftids{j}, r);
        end
        data.(rpname) = reflist;
    end
end

if any(char_i)
    %transpose character arrays because they are column-ordered
    %when read
    charPropNames = propnames(char_i);
    for j=1:length(charPropNames)
        cpname = charPropNames{j};
        data.(cpname) = data.(cpname) .';
    end
end
data = struct2table(data);
end