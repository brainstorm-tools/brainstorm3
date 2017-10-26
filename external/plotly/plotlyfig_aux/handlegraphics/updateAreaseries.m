function updateAreaseries(obj,areaIndex)

%-------------------------------------------------------------------------%

%-store original area handle-%
area_group = obj.State.Plot(areaIndex).Handle; 

%------------------------------------------------------------------------%

%-get children-%
area_child = get(area_group ,'Children'); 

%------------------------------------------------------------------------%

%-update patch -%
obj.State.Plot(areaIndex).Handle = area_child(1); 
updatePatch(obj,areaIndex); 

%------------------------------------------------------------------------%

%-revert handle-%
obj.State.Plot(areaIndex).Handle = area_group;

end



