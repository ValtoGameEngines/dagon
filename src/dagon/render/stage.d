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
import dlib.math.vector;
import dlib.image.color;

import dagon.core.event;
import dagon.core.bindings;
import dagon.core.time;
import dagon.graphics.entity;
import dagon.graphics.material;
import dagon.graphics.shader;
import dagon.graphics.state;
import dagon.render.pipeline;
import dagon.render.view;
import dagon.render.shaders.fallback;

class RenderStage: EventListener
{
    RenderPipeline pipeline;
    RenderView view;
    EntityGroup group;
    GraphicsState state;
    Material defaultMaterial;
    FallbackShader defaultShader;
    bool active = true;
    bool clear = true;

    this(RenderPipeline pipeline, EntityGroup group = null)
    {
        super(pipeline.eventManager, pipeline);
        this.pipeline = pipeline;
        this.group = group;
        pipeline.addStage(this);
        state.reset();
        defaultShader = New!FallbackShader(this);
        defaultMaterial = New!Material(defaultShader, this);
    }

    void update(Time t)
    {
        processEvents();

        if (view)
        {
            state.viewMatrix = view.viewMatrix();
            state.invViewMatrix = view.invViewMatrix();

            state.projectionMatrix = view.projectionMatrix();
            state.invProjectionMatrix = state.projectionMatrix.inverse;

            state.resolution = Vector2f(view.width, view.height);
            state.zNear = view.zNear;
            state.zFar = view.zFar;

            state.cameraPosition = view.cameraPosition;
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
                Color4f backgroundColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
                if (state.environment)
                    backgroundColor = state.environment.backgroundColor;

                glClearColor(
                    backgroundColor.r,
                    backgroundColor.g,
                    backgroundColor.b,
                    backgroundColor.a);
                glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
            }

            foreach(entity; group)
            if (entity.visible)
            {
                state.layer = entity.layer;

                state.modelViewMatrix = state.viewMatrix * entity.absoluteTransformation;
                state.normalMatrix = state.modelViewMatrix.inverse.transposed;

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
