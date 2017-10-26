function validatedir(status, mess, messid, filename)
    % check success of directory creation
    if (status == 0)
        if(~strcmp(messid, 'MATLAB:MKDIR:DirectoryExists'))
            error(['Error saving %s folder: ' mess ', ' messid ...
                   '. Please contact support@plot.ly for assistance.'], ... 
                   filename);           
        end
    end
end
