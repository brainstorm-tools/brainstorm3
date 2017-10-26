function gc = getGraphClass(obj)
if isHG2
    gc = lower(obj.Type);
else
    gc = lower(handle(obj).classhandle.name);
end
end