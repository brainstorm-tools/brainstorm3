function o = resolvePath(nwb, path)
dotTok = split(path, '.');
tokens = split(dotTok{1}, '/');
%skip first `/` if it exists
if isempty(tokens{1})
    tokens(1) = [];
end

%process slash tokens
o = nwb;
errmsg = 'Could not resolve path `%s`.';
while ~isempty(tokens)
    if isa(o, 'types.untyped.Set')
        [o, tokens] = resolveSet(o, tokens);
    elseif isa(o, 'types.untyped.Anon')
        [o, tokens] = resolveAnon(o, tokens);
    else
        [o, tokens] = resolveObj(o, tokens);
    end
    if isempty(o)
        error(errmsg, path);
    end
end
end

function [o, remainder] = resolveSet(obj, tokens)
tok = tokens{1};
if any(strcmp(keys(obj), tok))
    o = obj.get(tok);
    remainder = tokens(2:end);
else
    o = [];
    remainder = tokens;
end
end

function [o, remainder] = resolveAnon(obj, tokens)
tok = tokens{1};
if strcmp(obj.name, tok)
    o = obj.value;
    remainder = tokens(2:end);
else
    o = [];
    remainder = tokens;
end
end

function [o, remainder] = resolveObj(obj, tokens)
props = properties(obj);
toklen = length(tokens);
eagerlist = cell(toklen,1);
for i=1:toklen
    eagerlist{i} = strjoin(tokens(1:i), '_');
end
% stable in this case preserves ordering with eagerlist bias
[eagers, ei, ~] = intersect(eagerlist, props, 'stable');
if ~isempty(eagers)
    o = obj.(eagers{end});
    remainder = tokens(ei(end)+1:end);
    return;
end


% go one level down and check for sets
proplen = length(props);
issetprops = false(proplen, 1);
for i=1:proplen
    issetprops(i) = isa(obj.(props{i}), 'types.untyped.Set');
end
setprops = props(issetprops);
setpropslen = length(setprops);
minlen = length(tokens) + 1;
for i=1:setpropslen
    [new_o, new_tokens] = resolveSet(obj.(setprops{i}), tokens);
    new_toklen = length(new_tokens);
    if new_toklen < minlen
        o = new_o;
        remainder = new_tokens;
        minlen = new_toklen;
    end
end
end