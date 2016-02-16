
# What does it do?
Cocoapods-packager creates a static library or dynamic framework that contains your source code and all of its dependencies in one file. If you're trying to figure out how to make a closed-source cocoapod, you're in the right place.

## About dependency access
Packaging makes your dependencies available to your binary or framework internally, but not to code outside your binary or framework (your app, for example). So, If I'm just using Cocoapods normally and I have a local development pod that has some dependencies on, say, AFNetworking, I can import a class from my development pod like this:

`#import <MyPod/MyClass.h>` 

and from AFNetworking like this:

`#import <AFNetworking/AFNetworking.h>`

After packaging up that same development pod using Cocoapods-Packager, the import for `<MyPod/MyClass.h>` will work, but the import for ` <AFNetworking/AFNetworking.h>` (or any other dependencies) will not. Your application will need to pull in those dependencies itself (via Cocoapods or otherwise) to use them. 

## Should I use name mangling?
C-language name mangling is an arcane topic that is different for each language. (see [here](https://en.wikipedia.org/wiki/Name_mangling) and [here](http://stackoverflow.com/questions/5664690/how-can-i-find-out-the-symbol-name-the-compiler-generated-for-my-code)). 

But for our purposes, all we need to understand is why we'd want to mangle names. In the above example, we pretended to create a framework that contained a dependency on AFNetworking. If we enable name mangling when creating our framework, it will internally use the version of AFNetworking specified in our podspec dependency and allow the application to use whatever version of AFNetworking it wants to use. If you don't mangle, then there can be version (and obviously API) conflicts. For this particular use case, then, name mangling seems like a very good idea! 

Mangling is enabled by default in Cocoapods-Packager, but can be disabled using the `--no-mangle` switch.

## What about Cocoapods Rome?
[Cocoapods Rome](https://github.com/neonichu/Rome) is similar to Cocoapods-Packager, except that instead of creating one binary file that contains all dependencies, it creates one framework for your library source and separate frameworks for all of its dependencies. And unlike Cocoapods-Packager, it doesn't then create a podspec for you that would make it easy to serve all of those frameworks up with Cocoapods. The intended use case is to export frameworks for users that aren't using Cocoapods.

# Detailed Usage Instructions
## Got help?

```ruby
pod --help
pod lib --help
pod package --help
pod repo --help
pod spec --help
```

## Be in the right place
Obviously, `cd` into the directory that contains the podspec for the library you want to compile into a framework

## Lint first to find issues
- Use `--verbose` if you want to see what's going on. 
- Use `--sources` if you have some private pods. 
- And if you live in the real world, use `--allow-warnings`

```ruby
pod spec lint --verbose --sources=[private pods...],'https://github.com/CocoaPods/Specs.git' --allow-warnings --verbose
```

## Package it
To package up a framework that includes the source code of your pod and all of its dependencies:

```ruby
pod package MyLibrary.podspec --spec-sources=[private pods...],'https://github.com/CocoaPods/Specs.git' --embedded --force
```
- Make note of all of the possible switches

```
--force                                                         Overwrite existing
                                                                files.
--no-mangle                                                     Do not mangle
                                                                symbols of
                                                                depedendant Pods.
--embedded                                                      Generate embedded
                                                                frameworks.
--library                                                       Generate static
                                                                libraries.
--subspecs                                                      Only include the
                                                                given subspecs
--spec-sources=private,https://github.com/CocoaPods/Specs.git   The sources to
                                                                pull dependant
                                                                pods from
                                                                (defaults to
                                                                https://github.com/CocoaPods/Specs.git)
```

- Even after lint succeeds, packaging might still fail. This doesn't make sense, of course, but it is true. The linter seems to miss errors that the packager finds or vice versa. In reality, many things can go wrong in an Xcode build...
- Once your pod lints and packages successfully, take note of the nested podspec file and `iOS` directory that the packager created. (If your pod specifies development platforms other than iOS, directories with those names will be created instead).

## Create a new pod for framework distribution
Create a new pod somewhere else. (From here on out, I'll assume you've cd'd into your distribution repo):
```ruby
pod lib create [YourPodName]
```

Copy your 'iOS' directory and new podspec (see previous step) into the top level of this new directory. This is the pod you'll use to distribute your framework. The podspec that the packager created for you will have paths like this: 

```ruby
s.ios.preserve_paths          = 'iOS/MyFramework.embeddedframework/MyFramework.framework'
s.ios.public_header_files     = 'iOS/MyFramework.embeddedframework/MyFramework.framework/Versions/A/Headers/*.h'
```

which will jive with the paths in your new directory. To test that it works, point your app's Podfile to this new podspec and run `pod --verbose update`. 

```ruby
pod 'MyFramework', :path => '../../MyFrameWork/'
```

## Handle versioning as you would with any other pod
- If you don't understand Cocoapods' concept of 'semantic versioning', watch [this video](https://www.youtube.com/watch?v=x4ARXyovvPc)
- Increment `version` in your podspec

```ruby
s.version = '0.0.1'
```
- Make sure your framework distribution repo's podspec's source attribute looks something like this:

````ruby
s.source           = {
  :git => "https://github.com/CompanyName/RepoName.git", 
  :tag => s.version.to_s
}
```` 

- Connect your local framework distribution repo to a remote repo. Github walks you through this, but assuming you've made a repo on github, do this:

```ruby
git remote add origin https://github.com/CompanyName/RepoName.git
git push -u origin master
```
- Commit and push to make sure your actual code is in your remote repo before you tag it locally and push the tags.

```ruby
git commit -A 
git push -u origin master
```

- Tag your local repo and push that tag to your git remote
```ruby
git tag 0.0.1 #(make sure this matches s.version in your podspec) 
git push origin --tags
```
- If you mess up tagging or want to revert your tags for some reason, you can remove remote tags like this:

```ruby
git push --delete origin 0.0.1
```

and local tags like this:

```ruby
git tag -d 0.0.1
```

- If this is a private repo and you're working with it locally, don't forget to 

```ruby
pod repo update [YourRepoName]
```

and maybe

```ruby
pod repo push MyFramework MyFramework.podspec --allow-warnings
```

This last command will, as part of the push to your local repo, actually lint the new framework repo. 

## Test with remote repo
Point an application at your new framework. If you've gotten this far (linted and packaged) it should definitely work!

```ruby
pod 'MyFramework', :git => 'https://github.com/CompanyName/RepoName.git', :tag => '0.0.1'
```

# Known Issues / Limitations
Cocoapods-Packager can't produce a binary from a pod that contains Swift dependencies. See [here](https://github.com/CocoaPods/cocoapods-packager/issues/115) to track this issue. This limitation ends up causing a good deal of extra work. In my case, I was working with a single podspec that had mixed objective-c and Swift. To make use of the packager I had to refactor all of those swift dependencies into their own pods until the main library was objective-c only. 

# Possible Gotchas
**No headers created**
This can happen if your spec does not lint. The packager may successfully complete and create your framework, but there will be no headers. Without headers, nothing will work, so...

**The `source_files` pattern did not match any file**
The packager creates a podspec with these lines:

```ruby
s.platform = :ios, '9.0' 
s.ios.platform = :ios, '9.0'
```
If, as I did, you somehow find these unpleasantly redundant and remove the first one in a fit of pique, then the packager will think you're building for *ALL* frameworks, as you haven't specified one. So don't do that. Doing so can lead to errors that don't make sense in the platform you *think* you're building for (iOS), but apparently do in some other platform that you didn't know you were building for (Apple Watch, in this case...).

**Local (unneeded) podspecs don't lint**
Why isn't the podspec.json file in `Example/Pods/Local Podspecs` kept up to date? I didn't even create it and the linter complains aggressively about it! I deleted the `Local Podspecs` folder and have had no adverse effects.

**Not properly pointing at remote branch.**
If you're developing your library in a branch, don't forget to include the `:branch =>` directive in your source definition. The packager won't know that you've failed to point to the correct branch and might package your code just fine, but then the framework won't work correctly.

```ruby
s.source = {
	:git => "git@github.CompanyName/RepoName.git", 
	:branch => "BranchName"
}
```
