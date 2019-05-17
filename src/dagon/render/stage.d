/*
Copyright (c) 2019 Timur Gafarov

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

module dagon.render.stage;

import dlib.core.memory;
import dlib.core.ownership;

import dagon.core.bindings;
import dagon.core.time;
import dagon.graphics.entity;
import dagon.graphics.material;
import dagon.graphics.shader;
import dagon.graphics.shaders.defaultshader;
import dagon.graphics.state;
import dagon.render.pipeline;
import dagon.render.view;

class RenderStage: Owner
{
    RenderPipeline pipeline;
    RenderView view;
    EntityGroup group;
    State state;
    Material defaultMaterial;
    DefaultShader defaultShader;
    bool clear = true;
    
    this(RenderPipeline pipeline, EntityGroup group)
    {
        super(pipeline);
        this.pipeline = pipeline;
        this.group = group;
        pipeline.addStage(this);
        state.reset();
        defaultShader = New!DefaultShader(this);
        defaultMaterial = New!Material(defaultShader, this);
		defaultMaterial.depthWrite = false;
        defaultMaterial.culling = false;
    }

    void update(Time t)
    {
        if (view)
        {
            state.viewMatrix = view.viewMatrix();
            state.invViewMatrix = view.invViewMatrix();
            state.projectionMatrix = view.projectionMatrix();
        }
    }
    
    void render()
    {
        if (view && group)
        {
            glScissor(view.x, view.y, view.width, view.height);
            glViewport(view.x, view.y, view.width, view.height);
                
            if (clear)
            {
                glClearColor(
                    view.backgroundColor.r, 
                    view.backgroundColor.g,
                    view.backgroundColor.b,
                    view.backgroundColor.a);
                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            }
        
            foreach(entity; group)
            {
                state.modelViewMatrix = state.viewMatrix * entity.absoluteTransformation;
                
                if (entity.material)
                    entity.material.bind(&state);
                else
                    defaultMaterial.bind(&state);
                
                if (entity.drawable)
                    entity.drawable.render(&state);
                
                if (entity.material)
                    entity.material.unbind(&state);
                else
                    defaultMaterial.unbind(&state);
            }
        }
    }
}
