function versionStr = powerbimip_version()
%POWERBIMIP_VERSION Returns the current version of the PowerBiMIP toolkit.
%   It reads the version string from a 'VERSION' file located in the
%   project's root directory.

    versionStr = 'dev'; % Default version for development
    try
        % Get the full path of the currently running function
        funcPath = mfilename('fullpath');
        
        % Assume the 'VERSION' file is in the root directory, one level up
        % from the directory containing this function. Adjust the path if
        % your directory structure is different.
        [baseDir, ~, ~] = fileparts(funcPath);
        versionFilePath = fullfile(baseDir, '..', 'VERSION');
        
        fid = fopen(versionFilePath, 'r');
        if fid ~= -1
            versionStr = fgetl(fid);
            fclose(fid);
        end
    catch
        % If any error occurs, just return the default 'dev' string.
    end
end