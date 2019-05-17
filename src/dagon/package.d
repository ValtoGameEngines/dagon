/*
Copyright (c) 2017-2019 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon;

public
{
    import dlib;

    import dagon.core.application;
    import dagon.core.bindings;
    import dagon.core.config;
    import dagon.core.event;
    import dagon.core.input;
    import dagon.core.keycodes;
    import dagon.core.locale;
    import dagon.core.props;
    import dagon.core.time;
    import dagon.core.vfs;

    import dagon.graphics.camera;
    import dagon.graphics.drawable;
    import dagon.graphics.entity;
    import dagon.graphics.material;
    import dagon.graphics.mesh;
    import dagon.graphics.shader;
    import dagon.graphics.shaderloader;
    import dagon.graphics.shapes;
    import dagon.graphics.state;
    import dagon.graphics.texture;
    import dagon.graphics.updateable;
    import dagon.graphics.shaders.defaultshader;
    
    import dagon.render.framebuffer;
    import dagon.render.pipeline;
    import dagon.render.stage;
    import dagon.render.view;
    
    import dagon.resource.scene;
    
    import dagon.ui.font;
    import dagon.ui.freeview;
    import dagon.ui.ftfont;
	import dagon.ui.nuklear;
    import dagon.ui.textline;
}
